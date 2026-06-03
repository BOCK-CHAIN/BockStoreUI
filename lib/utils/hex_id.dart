import 'dart:convert';
import 'package:crypto/crypto.dart';

String generateHexId(
  String email,
  String password,
  String firstName,
  String lastName,
  String dob,
  String gender,
) {
  final input = "$email|$password|$firstName|$lastName|$dob|$gender";

  final bytes = utf8.encode(input);
  final digest = sha512.convert(bytes);
  final hexId = digest.toString().substring(0, 16);

  return hexId;
}
