mod auth;
mod db;

use auth::Auth;
use axum::{
    Extension, Router,
    extract::{Path, Query},
    http::StatusCode,
    response::{IntoResponse, Json},
    routing::get,
    serve,
};
use axum_extra::extract::CookieJar;
use db::init_db;
use serde::Deserialize;
use std::{net::SocketAddr, sync::Arc};
use tokio::net::TcpListener;

#[derive(Clone)]
struct AppState {
    db: sqlx::Pool<sqlx::Postgres>,
    auth: Arc<Auth>,
}

#[derive(Deserialize)]
struct QueryParams {
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

    let state = AppState {
        db: init_db().await?,
        auth: Arc::new(Auth::new()?),
    };

    let app = Router::new()
        .route("/units", get(unit))
        .route("/packs", get(packs))
        .route("/info/{filename}", get(unit_info))
        .layer(Extension(Arc::new(state)));

    let addr = SocketAddr::from(([127, 0, 0, 1], 8000));

    let listener = TcpListener::bind(addr).await?;

    serve(listener, app.into_make_service()).await?;

    Ok(())
}

async fn units(
    jar: CookieJar,
    Extension(state): Extension<Arc<AppState>>,
    Query(params): Query<QueryParams>,
) -> impl IntoResponse {
    let email = state.auth.validate(&jar).ok();

    let row: (serde_json::Value,) = match sqlx::query_as("SELECT get_units($1, $2, $3);")
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
    let row: (serde_json::Value,) = match sqlx::query_as("SELECT packs_json FROM units_packs_mv;")
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

async fn units_info(
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

    if email != "owner@gmail.com" {
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
