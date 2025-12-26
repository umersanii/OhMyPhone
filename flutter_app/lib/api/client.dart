import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../security/hmac.dart';
import 'models.dart';

class DaemonClient {
  final String baseUrl;
  final HmacAuth auth;

  DaemonClient({required this.baseUrl, required String secret})
      : auth = HmacAuth(secret);

  Future<ApiResponse<DeviceStatus>> getStatus() async {
    try {
      final headers = auth.generateHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/status'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(
          data: DeviceStatus.fromJson(data),
        );
      } else {
        return ApiResponse.error(
            'HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return ApiResponse.error('Connection failed: $e');
    }
  }

  Future<ApiResponse<void>> setDataEnabled(bool enabled) async {
    try {
      final body = jsonEncode({'enable': enabled});
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final message = body + timestamp;
      final key = utf8.encode(auth.secret);
      final bytes = utf8.encode(message);
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes).toString();

      // Print the exact values used in the request
      print('DEBUG: POST /radio/data');
      print('Body: $body');
      print('Timestamp: $timestamp');
      print('HMAC: $digest');

      final headers = {
        'Content-Type': 'application/json',
        'X-Auth': digest,
        'X-Time': timestamp,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/radio/data'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ApiResponse.success(
            message: 'Mobile data ${enabled ? 'enabled' : 'disabled'}');
      } else {
        return ApiResponse.error(
            'HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return ApiResponse.error('Request failed: $e');
    }
  }

  Future<ApiResponse<void>> setAirplaneMode(bool enabled) async {
    try {
      final body = jsonEncode({'enable': enabled});
      final headers = auth.generateHeaders(body: body);

      final response = await http
          .post(
            Uri.parse('$baseUrl/radio/airplane'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ApiResponse.success(
            message: 'Airplane mode ${enabled ? 'enabled' : 'disabled'}');
      } else {
        return ApiResponse.error(
            'HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return ApiResponse.error('Request failed: $e');
    }
  }

  Future<ApiResponse<void>> setCallForwarding(
      {required bool enable, String? number}) async {
    try {
      final body = jsonEncode({
        'enable': enable,
        if (number != null) 'number': number,
      });
      final headers = auth.generateHeaders(body: body);

      final response = await http
          .post(
            Uri.parse('$baseUrl/call/forward'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ApiResponse.success(
            message:
                'Call forwarding ${enable ? 'enabled' : 'disabled'}${number != null ? ' to $number' : ''}');
      } else {
        return ApiResponse.error(
            'HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return ApiResponse.error('Request failed: $e');
    }
  }

  Future<ApiResponse<void>> dialNumber(String number) async {
    try {
      final body = jsonEncode({'number': number});
      final headers = auth.generateHeaders(body: body);

      final response = await http
          .post(
            Uri.parse('$baseUrl/call/dial'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ApiResponse.success(message: 'Dialing $number');
      } else {
        return ApiResponse.error(
            'HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return ApiResponse.error('Request failed: $e');
    }
  }
}
