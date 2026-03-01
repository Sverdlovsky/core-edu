use anyhow::{Context, Result};
use axum::response::{IntoResponse, Redirect, Response};
use axum_extra::extract::CookieJar;
use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode, errors::ErrorKind};
use serde::Deserialize;
use serde_json;
use std::fs::File;

pub enum AuthError {
    MissingToken,
    ExpiredToken,
    InvalidToken,
}

#[derive(Debug, Deserialize)]
struct FileCreds {
    jwt_secret: String,
    callback: String,
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
        let file = File::open("keys/oauth.json").context("Failed to open keys/oauth.json")?;
        let fc: FileCreds =
            serde_json::from_reader(file).context("Failed to parse keys/oauth.json")?;

        Ok(Self {
            callback: fc.callback,
            decoding_key: DecodingKey::from_secret(fc.jwt_secret.as_bytes()),
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
