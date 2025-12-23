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
    data: bool,
    airplane: bool,
    call_forwarding: bool,
    uptime: u64,
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
    let data_output = ShellCommand::GetDataState.execute()
        .unwrap_or_default();
    let airplane_output = ShellCommand::GetAirplaneMode.execute()
        .unwrap_or_default();
    let uptime_output = ShellCommand::GetUptime.execute()
        .unwrap_or_default();
    let forwarding_output = ShellCommand::GetCallForwardingState.execute()
        .unwrap_or_default();

    // Parse outputs
    let (battery, charging) = shell::parse_battery(&battery_output);
    let signal_dbm = shell::parse_signal(&signal_output);
    let data = data_output.trim() == "1";
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
    };

    Ok(HttpResponse::Ok().json(response))
}
