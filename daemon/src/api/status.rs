use actix_web::{web, HttpRequest, HttpResponse, Result};
use serde::Serialize;
use std::sync::Arc;

use crate::auth::AuthService;
use crate::executor::shell::{self, ShellCommand};

#[derive(Serialize)]
pub struct StatusResponse {
    battery: i32,
    charging: bool,
    signal_dbm: i32,
    #[serde(rename = "data_enabled")]
    data: bool,
    #[serde(rename = "airplane_mode")]
    airplane: bool,
    #[serde(rename = "call_forwarding_active")]
    call_forwarding: bool,
    uptime: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    raw_battery: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    data_detection_method: Option<String>,
}

pub async fn get_status(
    req: HttpRequest,
    auth: web::Data<Arc<AuthService>>,
) -> Result<HttpResponse> {
    // Verify authentication (no body for GET)
    auth.verify_request(&req, &[])?;

    // Execute shell commands to gather status
    let battery_output = ShellCommand::GetBattery.execute()
        .unwrap_or_default();
    let signal_output = ShellCommand::GetSignal.execute()
        .unwrap_or_default();
    // Use robust mobile data detection
    let data_output = ShellCommand::GetMobileDataConnection.execute().unwrap_or_default();
    let data = crate::executor::shell::parse_mobile_data_connected(&data_output);
    let data_detection_method = "dumpsys_connectivity".to_string();
    let airplane_output = ShellCommand::GetAirplaneMode.execute()
        .unwrap_or_default();
    let uptime_output = ShellCommand::GetUptime.execute()
        .unwrap_or_default();
    let forwarding_output = ShellCommand::GetCallForwardingState.execute()
        .unwrap_or_default();

    // Parse outputs
    let (battery, charging) = shell::parse_battery(&battery_output);
    let signal_dbm = shell::parse_signal(&signal_output);
    let airplane = airplane_output.trim() == "1";
    let uptime = shell::parse_uptime(&uptime_output);
    let call_forwarding = shell::parse_call_forwarding(&forwarding_output);

    let response = StatusResponse {
        battery,
        charging,
        signal_dbm,
        data,
        airplane,
        call_forwarding,
        uptime,
        raw_battery: Some(battery_output),
        data_detection_method: Some(data_detection_method),
    };

    Ok(HttpResponse::Ok().json(response))
}
