import 'dart:convert';
import 'package:crypto/crypto.dart';

class SignUtil {
  static String generateSign(String param, String key, String customer) {
    final content = '$param$key$customer';
    final bytes = utf8.encode(content);
    final digest = md5.convert(bytes);
    return digest.toString().toUpperCase();
  }
}
