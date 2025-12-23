use actix_web::{error, Error, HttpRequest};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use std::collections::HashSet;
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

type HmacSha256 = Hmac<Sha256>;

pub struct AuthService {
    secret: Vec<u8>,
    timestamp_window: i64,
    used_nonces: Mutex<HashSet<String>>,
}

impl AuthService {
    pub fn new(secret: String, timestamp_window: i64) -> Self {
        Self {
            secret: secret.into_bytes(),
            timestamp_window,
            used_nonces: Mutex::new(HashSet::new()),
        }
    }

    /// Verify HMAC authentication from request headers
    pub fn verify_request(
        &self,
        req: &HttpRequest,
        body: &[u8],
    ) -> Result<(), Error> {
        // Extract headers
        let auth_header = req
            .headers()
            .get("X-Auth")
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| error::ErrorUnauthorized("Missing X-Auth header"))?;

        let time_header = req
            .headers()
            .get("X-Time")
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| error::ErrorUnauthorized("Missing X-Time header"))?;

        // Parse timestamp
        let timestamp: i64 = time_header
            .parse()
            .map_err(|_| error::ErrorBadRequest("Invalid timestamp"))?;

        // Check timestamp window (replay protection)
        let current_time = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64;

        let time_diff = (current_time - timestamp).abs() / 1000; // Convert to seconds
        if time_diff > self.timestamp_window {
            return Err(error::ErrorUnauthorized("Request expired"));
        }

        // Check nonce (prevent replay attacks)
        let nonce = format!("{}-{}", timestamp, auth_header);
        {
            let mut nonces = self.used_nonces.lock().unwrap();
            if nonces.contains(&nonce) {
                return Err(error::ErrorUnauthorized("Replay detected"));
            }
            nonces.insert(nonce);

            // Clean old nonces (keep last 1000)
            if nonces.len() > 1000 {
                nonces.clear();
            }
        }

        // Compute expected HMAC
        let message = [body, time_header.as_bytes()].concat();
        let mut mac = HmacSha256::new_from_slice(&self.secret)
            .map_err(|_| error::ErrorInternalServerError("HMAC initialization failed"))?;
        mac.update(&message);
        let expected = hex::encode(mac.finalize().into_bytes());

        // Compare HMAC
        if expected != auth_header {
            return Err(error::ErrorUnauthorized("Invalid signature"));
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::test::TestRequest;

    #[test]
    fn test_valid_hmac() {
        let auth = AuthService::new("test-secret".to_string(), 30);
        let body = b"test body";
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis()
            .to_string();

        let message = [body, timestamp.as_bytes()].concat();
        let mut mac = HmacSha256::new_from_slice(b"test-secret").unwrap();
        mac.update(&message);
        let signature = hex::encode(mac.finalize().into_bytes());

        let req = TestRequest::default()
            .insert_header(("X-Auth", signature.as_str()))
            .insert_header(("X-Time", timestamp.as_str()))
            .to_http_request();

        assert!(auth.verify_request(&req, body).is_ok());
    }

    #[test]
    fn test_missing_headers() {
        let auth = AuthService::new("test-secret".to_string(), 30);
        let req = TestRequest::default().to_http_request();
        assert!(auth.verify_request(&req, b"test").is_err());
    }
}
