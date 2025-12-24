import 'dart:convert';
import 'package:crypto/crypto.dart';

class HmacAuth {
  final String secret;

  HmacAuth(this.secret);

  Map<String, String> generateHeaders({String body = ''}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final message = body + timestamp;

    final key = utf8.encode(secret);
    final bytes = utf8.encode(message);

    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);

    return {
      'Content-Type': 'application/json',
      'X-Auth': digest.toString(),
      'X-Time': timestamp,
    };
  }
}
