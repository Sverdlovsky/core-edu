use anyhow::{Context, Result};
use axum::{
    Extension, Router,
    extract::{Path, Query},
    http::{
        header,
        HeaderValue,
        StatusCode,
        Method
    },
    response::{IntoResponse, Json},
    routing::{get, post},
    serve,
};
use axum_extra::extract::CookieJar;
use serde::Deserialize;
use std::{
    net::SocketAddr,
    time::Duration,
    sync::Arc,
    env,
};
use tokio::net::TcpListener;
use tower_http::cors::{CorsLayer};
use socket2::{Domain, Socket, Type};
use sqlx::{postgres::PgPoolOptions};
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
    decoding_key: DecodingKey,
}

impl Auth {
    pub fn new() -> anyhow::Result<Self> {
        let jwt_secret = env::var("JWT_SECRET").context("Environment variable JWT_SECRET not set!")?;

        Ok(Self {
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
}

#[derive(Clone)]
struct AppState {
    db: sqlx::Pool<sqlx::Postgres>,
    auth: Arc<Auth>,
}

#[derive(Deserialize)]
struct LearnQueryParams {
    source: Option<String>,
}

#[derive(Deserialize)]
struct SubmitResultQueryParams {
    wid: i64,
    time: f32,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let domain = env::var("DOMAIN").context("Environment variable DOMAIN is not set!")?;
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

    let cors = CorsLayer::new()
        .allow_origin([
            format!("https://{}", domain).parse::<HeaderValue>().unwrap(),
        ])
        .allow_credentials(true)
        .allow_methods([Method::GET, Method::POST])
        .allow_headers([header::CONTENT_TYPE]);

    let app = Router::new()
        .route("/health", get(health))
        .route("/ready", get(ready))
        .route("/word", get(next_word))
        .route("/result", post(submit_answer))
        .layer(Extension(Arc::new(state)))
        .layer(cors);


    let ipv4 = env::var("LISTEN_IPV4")
        .map(|v| v.eq_ignore_ascii_case("true"))
        .unwrap_or(true);

    let ipv4_listener = if ipv4 {
        let ipv4_addr: SocketAddr = format!(
            "{}:{}",
            env::var("LISTEN_IPV4_ADDR").unwrap_or_else(|_| "0.0.0.0".into()),
            env::var("LISTEN_IPV4_PORT").unwrap_or_else(|_| "8080".into()),
        )
        .parse()
        .context("Invalid IPv4 listen address")?;

        let socket = Socket::new(Domain::IPV4, Type::STREAM, None)?;

        socket.set_reuse_address(true)?;
        socket.bind(&ipv4_addr.into())?;
        socket.listen(1024)?;

        let std_listener: StdTcpListener = socket.into();
        std_listener.set_nonblocking(true)?;

        Some(TcpListener::from_std(std_listener)?)
    }

    let ipv6 = env::var("LISTEN_IPV6")
        .map(|v| v.eq_ignore_ascii_case("true"))
        .unwrap_or(false);

    let ipv6_listener = if ipv6 {
        let ipv6_addr: SocketAddr = format!(
            "[{}]:{}",
            env::var("LISTEN_IPV6_ADDR").unwrap_or_else(|_| "::".into()),
            env::var("LISTEN_IPV6_PORT").unwrap_or_else(|_| "8080".into()),
        )
        .parse()
        .context("Invalid IPv6 listen address")?;

        let socket = Socket::new(Domain::IPV6, Type::STREAM, None)?;

        socket.set_only_v6(true)?;
        socket.set_reuse_address(true)?;
        socket.bind(&ipv6_addr.into())?;
        socket.listen(1024)?;

        let std_listener: StdTcpListener = socket.into();
        std_listener.set_nonblocking(true)?;

        Some(TcpListener::from_std(std_listener)?)
    } else {
        None
    };

    match (ipv4_listener, ipv6_listener) {
        (Some(ipv4), Some(ipv6)) => {
            tokio::try_join!(
                serve(ipv4, app.clone()),
                serve(ipv6, app),
            )?;
        }
        (Some(ipv4), None) => {
            serve(ipv4, app).await?;
        }
        (None, Some(ipv6)) => {
            serve(ipv6, app).await?;
        }
        (None, None) => {
            anyhow::bail!("Both LISTEN_IPV4 and LISTEN_IPV6 are disabled");
        }
    }

    Ok(())
}

async fn health() -> StatusCode {
    StatusCode::OK
}

async fn ready() -> StatusCode {
    StatusCode::OK
}

async fn next_word(
    jar: CookieJar,
    Extension(state): Extension<Arc<AppState>>,
    Query(params): Query<LearnQueryParams>,
) -> impl IntoResponse {
    let email = match state.auth.validate(&jar) {
        Ok(email) => email,
        Err(_) => {
            return (StatusCode::UNAUTHORIZED).into_response();
        }
    };

    let row: (serde_json::Value,) = match sqlx::query_as("SELECT next_word($1);")
        //.bind(&params.source)
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

async fn submit_answer(
    jar: CookieJar,
    Extension(state): Extension<Arc<AppState>>,
    Json(payload): Json<SubmitResultQueryParams>,
) -> impl IntoResponse {
    let email = match state.auth.validate(&jar) {
        Ok(email) => email,
        Err(_) => {
            return (StatusCode::UNAUTHORIZED).into_response();
        }
    };

    let row: (serde_json::Value,) = match sqlx::query_as("SELECT submit_answer($1, $2, $3);")
        .bind(&email)
        .bind(payload.wid)
        .bind(payload.time)
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

