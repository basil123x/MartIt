import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Sends phone OTP over WhatsApp through Raqmee inbound API.
///
/// Dashboard (automation "Whatsapp Verification"):
///   API request received → Send message → Template `verify_otp_arb`
///   Body fields from that trigger: `phone`, `variable_1`, `button_1_url`
///   Toggle must be **مفعلة**, then Save.
class RaqmeeOtpService {
  RaqmeeOtpService._();

  static const inboundId = 'f0b8ae6b-f964-4e10-9109-4ad4994846dd';

  static const sendUrl =
      'https://raqmee.com/api/inbound/$inboundId/customers/send-message';

  /// Raqmee signing secret (dashboard → API trigger → Signing secret).
  static const String signatureKey =
      'nnTyZxcOlj0dSwZM7u2qZgk35dJXbshXp5VCoRmGUBTC4XSg';

  static bool get hasSignatureKey => signatureKey.trim().isNotEmpty;

  static String normalizePhone(String countryDialCode, String localNumber) {
    final dial = countryDialCode.trim();
    final local = localNumber.replaceAll(RegExp(r'\D'), '');
    if (dial.startsWith('+')) return '$dial$local';
    return '+$dial$local';
  }

  /// Docs: X-Raqmee-Signature: sha256=HMAC-SHA256("{timestamp}.{body}", secret)
  static String _sign({required String timestamp, required String body}) {
    final key = utf8.encode(signatureKey.trim());
    final bytes = utf8.encode('$timestamp.$body');
    final hex = Hmac(sha256, key).convert(bytes).toString();
    return 'sha256=$hex';
  }

  static Future<RaqmeeSendResult> sendOtp({
    required String countryDialCode,
    required String phoneNumber,
    required String otp,
  }) async {
    if (!hasSignatureKey) {
      return const RaqmeeSendResult(
        success: false,
        errorCode: 'missing_signature_key',
        errorMessage:
            'Raqmee signature key is empty. Paste it in RaqmeeOtpService.signatureKey.',
      );
    }

    final phone = normalizePhone(countryDialCode, phoneNumber);
    // Template verify_otp_arb: {{1}} = variable_1, copy-code button = button_1_url
    final bodyMap = <String, dynamic>{
      'phone': phone,
      'variable_1': otp,
      'button_1_url': otp,
    };
    final body = jsonEncode(bodyMap);
    final bodyBytes = utf8.encode(body);
    final timestamp =
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000).toString();
    final signature = _sign(timestamp: timestamp, body: body);

    try {
      final response = await Dio().post(
        sendUrl,
        data: bodyBytes,
        options: Options(
          contentType: 'application/json',
          responseType: ResponseType.plain,
          headers: {
            'Accept': 'application/json',
            'Accept-Language': 'en',
            'X-Raqmee-Timestamp': timestamp,
            'X-Raqmee-Signature': signature,
            'User-Agent': 'MartIt/1.0',
            'Content-Length': bodyBytes.length.toString(),
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final decoded = _decode(response.data);
      final ok = response.statusCode == 200 &&
          (decoded['status']?.toString() == 'success' ||
              decoded['success'] == true ||
              decoded['error'] == null);

      if (ok) {
        return RaqmeeSendResult(success: true, raw: decoded);
      }

      final err = decoded['error'];
      String code = 'send_failed';
      String message = 'Failed to send WhatsApp OTP';
      if (err is Map) {
        code = err['code']?.toString() ?? code;
        message = err['message']?.toString() ?? message;
      } else if (decoded['message'] != null) {
        message = decoded['message'].toString();
      }

      if (code == 'validation_failed' ||
          message.contains('مطلوب') ||
          message.toLowerCase().contains('required')) {
        message =
            'رقمي رفض الطلب. تأكد أن أتمتة Whatsapp Verification '
            'مفعّلة (مش "غير مفعلة") واضغط حفظ، '
            'وأن القالب verify_otp_arb مختار.';
        code = 'validation_failed';
      }

      return RaqmeeSendResult(
        success: false,
        errorCode: code,
        errorMessage: message,
        statusCode: response.statusCode,
        raw: decoded,
      );
    } catch (e) {
      return RaqmeeSendResult(
        success: false,
        errorCode: 'network_error',
        errorMessage: e.toString(),
      );
    }
  }

  static Map<String, dynamic> _decode(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is! String) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }
}

class RaqmeeSendResult {
  final bool success;
  final String? errorCode;
  final String? errorMessage;
  final int? statusCode;
  final Map<String, dynamic>? raw;

  const RaqmeeSendResult({
    required this.success,
    this.errorCode,
    this.errorMessage,
    this.statusCode,
    this.raw,
  });
}
