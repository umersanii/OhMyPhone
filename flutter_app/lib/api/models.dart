// API response models for OhMyPhone daemon

class DeviceStatus {
  final int battery;
  final int signal;
  final bool dataEnabled;
  final bool airplaneMode;
  final bool callForwardingActive;
  final String? forwardingNumber;

  DeviceStatus({
    required this.battery,
    required this.signal,
    required this.dataEnabled,
    required this.airplaneMode,
    required this.callForwardingActive,
    this.forwardingNumber,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      battery: json['battery'] ?? 0,
      signal: json['signal'] ?? 0,
      dataEnabled: json['data_enabled'] ?? false,
      airplaneMode: json['airplane_mode'] ?? false,
      callForwardingActive: json['call_forwarding_active'] ?? false,
      forwardingNumber: json['forwarding_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'battery': battery,
      'signal': signal,
      'data_enabled': dataEnabled,
      'airplane_mode': airplaneMode,
      'call_forwarding_active': callForwardingActive,
      'forwarding_number': forwardingNumber,
    };
  }
}

class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory ApiResponse.success({T? data, String? message}) {
    return ApiResponse(
      success: true,
      data: data,
      message: message,
    );
  }

  factory ApiResponse.error(String message) {
    return ApiResponse(
      success: false,
      message: message,
    );
  }
}
