use actix_web::{web, HttpRequest, HttpResponse, Result};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

use crate::auth::AuthService;
use crate::executor::shell::ShellCommand;

#[derive(Deserialize, Serialize)]
pub struct DataToggleRequest {
    enable: bool,
}

#[derive(Serialize)]
pub struct DataToggleResponse {
    success: bool,
    enabled: bool,
    message: String,
}

/// POST /radio/data - Toggle mobile data on/off
pub async fn toggle_data(
    req: HttpRequest,
    body: web::Json<DataToggleRequest>,
    auth: web::Data<Arc<AuthService>>,
) -> Result<HttpResponse> {
    // Extract the inner value for HMAC verification and later use
    let data_request = body.into_inner();
    
    // Serialize body for HMAC verification
    let body_bytes = serde_json::to_vec(&data_request)
        .map_err(|e| actix_web::error::ErrorBadRequest(format!("Invalid JSON: {}", e)))?;

    // Verify authentication
    auth.verify_request(&req, &body_bytes)?;

    // Execute appropriate command based on enable flag
    let command = if data_request.enable {
        ShellCommand::EnableData
    } else {
        ShellCommand::DisableData
    };

    match command.execute() {
        Ok(_) => {
            let response = DataToggleResponse {
                success: true,
                enabled: data_request.enable,
                message: format!("Mobile data {}", if data_request.enable { "enabled" } else { "disabled" }),
            };
            Ok(HttpResponse::Ok().json(response))
        }
        Err(e) => {
            let response = DataToggleResponse {
                success: false,
                enabled: !data_request.enable, // Assume it stayed in previous state
                message: format!("Failed to toggle data: {}", e),
            };
            Ok(HttpResponse::InternalServerError().json(response))
        }
    }
}
