class PasswordResetTokenStatus {
  const PasswordResetTokenStatus({
    required this.valid,
    required this.maskedEmail,
  });

  factory PasswordResetTokenStatus.fromJson(Map<String, dynamic> json) =>
      PasswordResetTokenStatus(
        valid: json['valid'] as bool? ?? false,
        maskedEmail: json['maskedEmail'] as String? ?? '',
      );

  final bool valid;
  final String maskedEmail;
}
