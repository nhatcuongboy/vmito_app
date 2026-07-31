import 'package:vmito_app/features/session/domain/session_player.dart';

enum PaymentStatus {
  pending,
  submitted,
  approved,
  rejected;

  factory PaymentStatus.fromJson(String value) => switch (value) {
    'SUBMITTED' => submitted,
    'APPROVED' => approved,
    'REJECTED' => rejected,
    _ => pending,
  };
}

enum PaymentMethod {
  cash,
  bankTransfer;

  factory PaymentMethod.fromJson(String value) =>
      value == 'BANK_TRANSFER' ? bankTransfer : cash;
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.playerId,
    required this.amount,
    required this.status,
    this.paymentMethod,
    this.hostNotes,
    this.proofNotes,
    this.player,
    this.sessionName,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
    id: json['id'] as String,
    playerId: json['playerId'] as String,
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    status: PaymentStatus.fromJson(json['status'] as String? ?? 'PENDING'),
    paymentMethod: json['paymentMethod'] is String
        ? PaymentMethod.fromJson(json['paymentMethod'] as String)
        : null,
    hostNotes: json['hostNotes'] as String?,
    proofNotes: json['proofNotes'] as String?,
    player: json['player'] is Map
        ? SessionPlayer.fromJson(
            Map<String, dynamic>.from(json['player'] as Map),
          )
        : null,
    sessionName: json['session'] is Map
        ? (json['session'] as Map)['name'] as String?
        : null,
  );

  final String id;
  final String playerId;
  final int amount;
  final PaymentStatus status;
  final PaymentMethod? paymentMethod;
  final String? hostNotes;
  final String? proofNotes;
  final SessionPlayer? player;
  final String? sessionName;
}

class PaymentStats {
  const PaymentStats({
    this.total = 0,
    this.pending = 0,
    this.submitted = 0,
    this.approved = 0,
    this.rejected = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
  });

  factory PaymentStats.fromJson(Map<String, dynamic> json) => PaymentStats(
    total: (json['total'] as num?)?.toInt() ?? 0,
    pending: (json['pending'] as num?)?.toInt() ?? 0,
    submitted: (json['submitted'] as num?)?.toInt() ?? 0,
    approved: (json['approved'] as num?)?.toInt() ?? 0,
    rejected: (json['rejected'] as num?)?.toInt() ?? 0,
    totalAmount: (json['totalAmount'] as num?)?.toInt() ?? 0,
    paidAmount: (json['paidAmount'] as num?)?.toInt() ?? 0,
  );

  final int total;
  final int pending;
  final int submitted;
  final int approved;
  final int rejected;
  final int totalAmount;
  final int paidAmount;
}

class PaymentLedger {
  const PaymentLedger({required this.payments, required this.stats});

  factory PaymentLedger.fromJson(Map<String, dynamic> json) => PaymentLedger(
    payments: (json['payments'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(PaymentRecord.fromJson)
        .toList(growable: false),
    stats: PaymentStats.fromJson(
      json['stats'] as Map<String, dynamic>? ?? const {},
    ),
  );

  final List<PaymentRecord> payments;
  final PaymentStats stats;
}

class HostPaymentSettings {
  const HostPaymentSettings({
    required this.id,
    this.bankName,
    this.bankAccountNumber,
    this.accountHolderName,
    this.qrCodeUrl,
    this.isDefault = false,
  });

  factory HostPaymentSettings.fromJson(Map<String, dynamic> json) =>
      HostPaymentSettings(
        id: json['id'] as String,
        bankName: json['bankName'] as String?,
        bankAccountNumber: json['bankAccountNumber'] as String?,
        accountHolderName: json['accountHolderName'] as String?,
        qrCodeUrl: json['qrCodeUrl'] as String?,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  final String id;
  final String? bankName;
  final String? bankAccountNumber;
  final String? accountHolderName;
  final String? qrCodeUrl;
  final bool isDefault;
}

class SessionExpense {
  const SessionExpense({
    required this.id,
    required this.name,
    required this.amount,
  });

  factory SessionExpense.fromJson(Map<String, dynamic> json) => SessionExpense(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String name;
  final int amount;
}

class HostTransactionSummary {
  const HostTransactionSummary({
    required this.userId,
    required this.userName,
    required this.totalSessions,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    this.userImage,
  });

  factory HostTransactionSummary.fromJson(Map<String, dynamic> json) =>
      HostTransactionSummary(
        userId: json['userId'] as String? ?? 'guest',
        userName: json['userName'] as String? ?? '',
        userImage: json['userImage'] as String?,
        totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
        totalAmount: (json['totalAmount'] as num?)?.toInt() ?? 0,
        paidAmount: (json['paidAmount'] as num?)?.toInt() ?? 0,
        pendingAmount: (json['pendingAmount'] as num?)?.toInt() ?? 0,
      );

  final String userId;
  final String userName;
  final String? userImage;
  final int totalSessions;
  final int totalAmount;
  final int paidAmount;
  final int pendingAmount;
}
