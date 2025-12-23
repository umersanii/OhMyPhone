use actix_web::{web, HttpRequest, HttpResponse, Result};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

use crate::auth::AuthService;
use crate::executor::shell::ShellCommand;

#[derive(Deserialize, Serialize)]
pub struct CallForwardRequest {
    enable: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    number: Option<String>,
}

#[derive(Serialize)]
pub struct CallForwardResponse {
    success: bool,
    enabled: bool,
    message: String,
}

#[derive(Deserialize, Serialize)]
pub struct CallDialRequest {
    number: String,
}

#[derive(Serialize)]
pub struct CallDialResponse {
    success: bool,
    message: String,
}

/// POST /call/forward - Configure call forwarding
pub async fn set_call_forwarding(
    req: HttpRequest,
    body: web::Json<CallForwardRequest>,
    auth: web::Data<Arc<AuthService>>,
) -> Result<HttpResponse> {
    // Extract the inner value for HMAC verification and later use
    let forward_request = body.into_inner();

    // Validate request: if enabling, number must be provided
    if forward_request.enable && forward_request.number.is_none() {
        return Ok(HttpResponse::BadRequest().json(CallForwardResponse {
            success: false,
            enabled: false,
            message: "Number required when enabling call forwarding".to_string(),
        }));
    }

    // Serialize body for HMAC verification
    let body_bytes = serde_json::to_vec(&forward_request)
        .map_err(|e| actix_web::error::ErrorBadRequest(format!("Invalid JSON: {}", e)))?;

    // Verify authentication
    auth.verify_request(&req, &body_bytes)?;

    // Validate phone number format if enabling
    if forward_request.enable {
        if let Some(ref number) = forward_request.number {
            if !is_valid_phone_number(number) {
                return Ok(HttpResponse::BadRequest().json(CallForwardResponse {
                    success: false,
                    enabled: false,
                    message: "Invalid phone number format".to_string(),
                }));
            }
        }
    }

    // Execute appropriate command
    let command = if forward_request.enable {
        // Safe: we validated number exists and format above
        ShellCommand::EnableCallForwarding(forward_request.number.unwrap())
    } else {
        ShellCommand::DisableCallForwarding
    };

    match command.execute() {
        Ok(_) => {
            let response = CallForwardResponse {
                success: true,
                enabled: forward_request.enable,
                message: format!(
                    "Call forwarding {}",
                    if forward_request.enable { "enabled" } else { "disabled" }
                ),
            };
            Ok(HttpResponse::Ok().json(response))
        }
        Err(e) => {
            let response = CallForwardResponse {
                success: false,
                enabled: !forward_request.enable, // Assume it stayed in previous state
                message: format!("Failed to set call forwarding: {}", e),
            };
            Ok(HttpResponse::InternalServerError().json(response))
        }
    }
}

/// Validate phone number format
/// Accepts: +1234567890, 1234567890, or international format
fn is_valid_phone_number(number: &str) -> bool {
    // Must start with + or digit
    if number.is_empty() {
        return false;
    }

    let mut chars = number.chars();
    let first = chars.next().unwrap();

    if first != '+' && !first.is_ascii_digit() {
        return false;
    }

    // Rest must be digits (allowing + only at start)
    let rest: String = chars.collect();
    if rest.is_empty() {
        return false;
    }

    // Check all remaining chars are digits
    if !rest.chars().all(|c| c.is_ascii_digit()) {
        return false;
    }

    // Length check: reasonable phone numbers are 7-15 digits
    let digit_count = number.chars().filter(|c| c.is_ascii_digit()).count();
    (7..=15).contains(&digit_count)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_phone_numbers() {
        assert!(is_valid_phone_number("+1234567890"));
        assert!(is_valid_phone_number("1234567890"));
        assert!(is_valid_phone_number("+919876543210"));
        assert!(is_valid_phone_number("7654321"));
    }

    #[test]
    fn test_invalid_phone_numbers() {
        assert!(!is_valid_phone_number(""));
        assert!(!is_valid_phone_number("+"));
        assert!(!is_valid_phone_number("abc123"));
        assert!(!is_valid_phone_number("+123abc"));
        assert!(!is_valid_phone_number("123-456-7890")); // No dashes
        assert!(!is_valid_phone_number("123")); // Too short
        assert!(!is_valid_phone_number("12345678901234567890")); // Too long
    }
}

/// POST /call/dial - Initiate a phone call
pub async fn dial_call(
    req: HttpRequest,
    body: web::Json<CallDialRequest>,
    auth: web::Data<Arc<AuthService>>,
) -> Result<HttpResponse> {
    // Extract the inner value for HMAC verification
    let dial_request = body.into_inner();

    // Serialize body for HMAC verification
    let body_bytes = serde_json::to_vec(&dial_request)
        .map_err(|e| actix_web::error::ErrorBadRequest(format!("Invalid JSON: {}", e)))?;

    // Verify authentication
    auth.verify_request(&req, &body_bytes)?;

    // Validate phone number format
    if !is_valid_phone_number(&dial_request.number) {
        return Ok(HttpResponse::BadRequest().json(CallDialResponse {
            success: false,
            message: "Invalid phone number format".to_string(),
        }));
    }

    // Execute dial command
    let command = ShellCommand::DialNumber(dial_request.number.clone());

    match command.execute() {
        Ok(_) => {
            let response = CallDialResponse {
                success: true,
                message: format!("Dialing {}", dial_request.number),
            };
            Ok(HttpResponse::Ok().json(response))
        }
        Err(e) => {
            let response = CallDialResponse {
                success: false,
                message: format!("Failed to initiate call: {}", e),
            };
            Ok(HttpResponse::InternalServerError().json(response))
        }
    }
}
