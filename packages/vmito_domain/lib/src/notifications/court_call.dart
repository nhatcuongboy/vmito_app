class CourtCall {
  const CourtCall({
    required this.userId,
    required this.sessionId,
    required this.courtNumber,
    this.courtId,
    this.courtName,
  });

  final String userId;
  final String sessionId;
  final String? courtId;
  final String? courtName;
  final int courtNumber;

  String get fingerprint => '$userId:$sessionId:${courtId ?? courtNumber}';

  static CourtCall? tryParse(Map<String, dynamic> data) {
    final userId = _string(data['userId']);
    final sessionId = _string(data['sessionId']);
    final rawNumber = data['courtNumber'];
    final courtNumber = rawNumber is int
        ? rawNumber
        : int.tryParse(rawNumber?.toString() ?? '');
    if (userId == null || sessionId == null || courtNumber == null) return null;
    return CourtCall(
      userId: userId,
      sessionId: sessionId,
      courtNumber: courtNumber,
      courtId: _string(data['courtId']),
      courtName: _string(data['courtName']),
    );
  }

  static String? _string(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }
}
