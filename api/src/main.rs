use anyhow::{Context, Result};
use axum::{
    Extension, Router,
    extract::{Path, Query},
    http::StatusCode,
    response::{
        IntoResponse,
        Redirect,
        Response,
        Json,
    },
    routing::get,
    serve,
};
use axum_extra::extract::CookieJar;
use serde::Deserialize;
use std::{
    net::SocketAddr,
    time::Duration,
    sync::Arc,
    fs::File,
    env,
};
use tokio::net::TcpListener;
use sqlx::{
    postgres::PgPoolOptions,
    Postgres,
    Pool,
};
use num_cpus;
use jsonwebtoken::{
    Algorithm,
    DecodingKey,
    Validation,
    decode,
    errors::ErrorKind,
};

pub enum AuthError {
    MissingToken,
    ExpiredToken,
    InvalidToken,
}

#[derive(Debug, Deserialize)]
pub struct Claims {
    pub sub: String,
    //pub exp: usize,
}

pub struct Auth {
    callback: String,
    decoding_key: DecodingKey,
}

impl Auth {
    pub fn new() -> anyhow::Result<Self> {
        let jwt_secret = env::var("JWT_SECRET").context("Environment variable JWT_SECRET not set!")?;
        let domain = env::var("DOMAIN").context("Environment variable DOMAIN not set!")?;

        Ok(Self {
            callback: format!("https://auth.{}/with/yandex", domain),
            decoding_key: DecodingKey::from_secret(jwt_secret.as_bytes()),
        })
    }

    pub fn validate(&self, jar: &CookieJar) -> Result<String, AuthError> {
        let token = match jar.get("access_token") {
            Some(c) => c.value().to_string(),
            None => return Err(AuthError::MissingToken),
        };

        let mut validation = Validation::new(Algorithm::HS256);
        validation.validate_exp = true;

        let token_data = match decode::<Claims>(&token, &self.decoding_key, &validation) {
            Ok(data) => data,
            Err(err) => match *err.kind() {
                ErrorKind::ExpiredSignature => return Err(AuthError::ExpiredToken),
                _ => return Err(AuthError::InvalidToken),
            },
        };

        Ok(token_data.claims.sub)
    }

    pub fn force_validate(&self, jar: &CookieJar) -> Result<String, Response> {
        let token = match jar.get("access_token") {
            Some(c) => c.value().to_string(),
            None => {
                return Err(Redirect::temporary(&self.callback).into_response());
            }
        };

        let mut validation = Validation::new(Algorithm::HS256);
        validation.validate_exp = true;

        let token_data = match decode::<Claims>(&token, &self.decoding_key, &validation) {
            Ok(data) => data,
            Err(err) => match *err.kind() {
                ErrorKind::ExpiredSignature => {
                    return Err(Redirect::temporary(&self.callback).into_response());
                }
                _ => return Err(Redirect::temporary(&self.callback).into_response()),
            },
        };

        Ok(token_data.claims.sub)
    }
}

#[derive(Clone)]
struct AppState {
    db: sqlx::Pool<sqlx::Postgres>,
    auth: Arc<Auth>,
}

#[derive(Deserialize)]
struct SeriesQueryParams {
    offset: Option<i32>,
    limit: Option<i32>,
    search: Option<String>,
}

#[derive(Deserialize)]
struct LearnQueryParams {
    source: Option<String>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let dsn = env::var("DATABASE_URL").context("Environment variable DATABASE_URL not set!")?;
    let pool = PgPoolOptions::new()
        .max_connections(num_cpus::get() as u32 * 2)
        .idle_timeout(Duration::from_secs(300))
        .connect(dsn.as_str())
        .await
        .context("Failed to connect to Postgres")?;

    let state = AppState {
        db: pool,
        auth: Arc::new(Auth::new()?),
    };

    let app = Router::new()
        .route("/series", get(series))
        .route("/packs", get(packs))
        .route("/info/{filename}", get(series_info))
        .layer(Extension(Arc::new(state)));

    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));

    let listener = TcpListener::bind(addr).await?;

    serve(listener, app.into_make_service()).await?;

    Ok(())
}

async fn series(
    jar: CookieJar,
    Extension(state): Extension<Arc<AppState>>,
    Query(params): Query<SeriesQueryParams>,
) -> impl IntoResponse {
    let email = state.auth.validate(&jar).ok();

    let row: (serde_json::Value,) = match sqlx::query_as("SELECT get_series($1, $2, $3);")
        .bind(&params.offset)
        .bind(&params.limit)
        //.bind(&params.search)
        .bind(&email)
        .fetch_one(&state.db)
        .await
    {
        Ok(r) => r,
        Err(e) => {
            eprintln!("DB error: {}", e);
            return (StatusCode::INTERNAL_SERVER_ERROR, "db error").into_response();
        }
    };

    (StatusCode::OK, Json(row.0)).into_response()
}

async fn packs(Extension(state): Extension<Arc<AppState>>) -> impl IntoResponse {
    let row: (serde_json::Value,) = match sqlx::query_as("SELECT packs_json FROM series_packs_mv;")
        .fetch_one(&state.db)
        .await
    {
        Ok(r) => r,
        Err(e) => {
            eprintln!("DB error: {}", e);
            return (StatusCode::INTERNAL_SERVER_ERROR, "db error").into_response();
        }
    };

    (StatusCode::OK, Json(row.0)).into_response()
}

async fn series_info(
    jar: CookieJar,
    Extension(state): Extension<Arc<AppState>>,
    Path(filename): Path<String>,
) -> impl IntoResponse {
    let email = match state.auth.validate(&jar) {
        Ok(email) => email,
        Err(_) => {
            return (StatusCode::FORBIDDEN, "Access denied").into_response();
        }
    };

    let admin_email = env::var("ADMIN_EMAIL").unwrap_or_else(|_| "no-reply@gmail.com".to_string());
    if email != admin_email {
        return (StatusCode::FORBIDDEN, "Access denied").into_response();
    }

    let row: (serde_json::Value,) =
        match sqlx::query_as("SELECT video.get_video_meta(('0x'||$1)::smallint);")
            .bind(filename)
            .fetch_one(&state.db)
            .await
        {
            Ok(r) => r,
            Err(e) => {
                eprintln!("DB error: {}", e);
                return (StatusCode::INTERNAL_SERVER_ERROR, "db error").into_response();
            }
        };

    (StatusCode::OK, Json(row.0)).into_response()
}

async fn next_word(
    jar: CookieJar,
    Extension(state): Extension<Arc<AppState>>,
    Query(params): Query<LearnQueryParams>,
) -> impl IntoResponse {
    let email = state.auth.validate(&jar).ok();

    let row: (serde_json::Value,) = match sqlx::query_as("SELECT get_word($1, $2);")
        .bind(&params.source)
        .bind(&email)
        .fetch_one(&state.db)
        .await
    {
        Ok(r) => r,
        Err(e) => {
            eprintln!("DB error: {}", e);
            return (StatusCode::INTERNAL_SERVER_ERROR, "db error").into_response();
        }
    };

    (StatusCode::OK, Json(row.0)).into_response()
}

