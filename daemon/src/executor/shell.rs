use std::process::Command;

/// Whitelisted shell commands - NO arbitrary execution
#[derive(Debug)]
pub enum ShellCommand {
    GetBattery,
    GetSignal,
    GetDataState,
    GetAirplaneMode,
    GetUptime,
    EnableData,
    DisableData,
    EnableAirplaneMode,
    DisableAirplaneMode,
    EnableCallForwarding(String),
    DisableCallForwarding,
    GetCallForwardingState,
    DialNumber(String),
}

impl ShellCommand {
    /// Execute the whitelisted command and return output
    pub fn execute(&self) -> Result<String, String> {
        let output = match self {
            ShellCommand::GetBattery => {
                Command::new("dumpsys")
                    .arg("battery")
                    .output()
            }
            ShellCommand::GetSignal => {
                Command::new("dumpsys")
                    .arg("telephony.registry")
                    .output()
            }
            ShellCommand::GetDataState => {
                Command::new("settings")
                    .args(["get", "global", "mobile_data"])
                    .output()
            }
            ShellCommand::GetAirplaneMode => {
                Command::new("settings")
                    .args(["get", "global", "airplane_mode_on"])
                    .output()
            }
            ShellCommand::GetUptime => {
                Command::new("cat")
                    .arg("/proc/uptime")
                    .output()
            }
            ShellCommand::EnableData => {
                Command::new("svc")
                    .args(["data", "enable"])
                    .output()
            }
            ShellCommand::DisableData => {
                Command::new("svc")
                    .args(["data", "disable"])
                    .output()
            }
            ShellCommand::EnableAirplaneMode => {
                // Use cmd connectivity for reliable airplane mode control
                Command::new("cmd")
                    .args(["connectivity", "airplane-mode", "enable"])
                    .output()
            }
            ShellCommand::DisableAirplaneMode => {
                // Use cmd connectivity for reliable airplane mode control
                Command::new("cmd")
                    .args(["connectivity", "airplane-mode", "disable"])
                    .output()
            }
            ShellCommand::EnableCallForwarding(number) => {
                // service call phone 14 i32 1 s16 "*21*+1234567890#"
                // The phone number is already validated in the API layer
                let code = format!("*21*{}#", number);
                Command::new("service")
                    .args(["call", "phone", "14", "i32", "1", "s16", &code])
                    .output()
            }
            ShellCommand::DisableCallForwarding => {
                // service call phone 14 i32 1 s16 "#21#"
                Command::new("service")
                    .args(["call", "phone", "14", "i32", "1", "s16", "#21#"])
                    .output()
            }
            ShellCommand::GetCallForwardingState => {
                // Query call forwarding status
                // service call phone 13 i32 1 i32 0
                Command::new("service")
                    .args(["call", "phone", "13", "i32", "1", "i32", "0"])
                    .output()
            }
            ShellCommand::DialNumber(number) => {
                // am start -a android.intent.action.CALL -d tel:<number>
                // Phone number is already validated in API layer
                let tel_uri = format!("tel:{}", number);
                Command::new("am")
                    .args(["start", "-a", "android.intent.action.CALL", "-d", &tel_uri])
                    .output()
            }
        };

        match output {
            Ok(out) if out.status.success() => {
                Ok(String::from_utf8_lossy(&out.stdout).to_string())
            }
            Ok(out) => {
                let stderr = String::from_utf8_lossy(&out.stderr);
                Err(format!("Command failed: {}", stderr))
            }
            Err(e) => Err(format!("Execution error: {}", e)),
        }
    }
}

/// Parse battery dumpsys output
pub fn parse_battery(output: &str) -> (i32, bool) {
    let mut level = 0;
    let mut charging = false;

    for line in output.lines() {
        if line.contains("level:") {
            if let Some(val) = line.split(':').nth(1) {
                level = val.trim().parse().unwrap_or(0);
            }
        }
        if line.contains("status:") {
            charging = line.contains("Charging") || line.contains("2");
        }
    }

    (level, charging)
}

/// Parse signal strength from telephony registry
pub fn parse_signal(output: &str) -> i32 {
    for line in output.lines() {
        if line.contains("mSignalStrength") || line.contains("SignalStrength") {
            // Look for dbm value (typically -50 to -120)
            if let Some(pos) = line.find("rssi=") {
                let rest = &line[pos + 5..];
                if let Some(end) = rest.find(|c: char| !c.is_numeric() && c != '-') {
                    if let Ok(dbm) = rest[..end].trim().parse::<i32>() {
                        return dbm;
                    }
                }
            }
        }
    }
    -999 // Unknown
}

/// Parse uptime in seconds
pub fn parse_uptime(output: &str) -> u64 {
    output
        .split_whitespace()
        .next()
        .and_then(|s| s.parse::<f64>().ok())
        .map(|f| f as u64)
        .unwrap_or(0)
}

/// Parse call forwarding state
/// The service call output is complex, but we can check for specific indicators
pub fn parse_call_forwarding(output: &str) -> bool {
    // The output from "service call phone 13" is parcel data
    // When call forwarding is active, the response contains non-zero status codes
    // This is a simplified heuristic - may need adjustment based on device

    // Look for "Result: Parcel" which indicates a response
    if !output.contains("Result: Parcel") {
        return false;
    }

    // If there's actual forwarding data, the parcel will be non-empty
    // A simple heuristic: more than 50 chars of output suggests active forwarding
    output.len() > 50
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_battery() {
        let output = "  level: 82\n  status: 3\n";
        let (level, charging) = parse_battery(output);
        assert_eq!(level, 82);
    }

    #[test]
    fn test_parse_uptime() {
        let output = "12345.67 98765.43";
        assert_eq!(parse_uptime(output), 12345);
    }
}
