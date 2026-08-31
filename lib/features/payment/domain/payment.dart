import 'package:meta/meta.dart';
import 'package:vmito_app/shared/models/session_player.dart';

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
    required this.createdAt,
    this.registeredByUserId,
    this.paymentMethod,
    this.hostNotes,
    this.proofNotes,
    this.proofImageUrl,
    this.submittedAt,
    this.player,
    this.session,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
    id: json['id'] as String,
    playerId: json['playerId'] as String,
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    status: PaymentStatus.fromJson(json['status'] as String? ?? 'PENDING'),
    createdAt:
        _dateTime(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    registeredByUserId: json['registeredByUserId'] as String?,
    paymentMethod: json['paymentMethod'] is String
        ? PaymentMethod.fromJson(json['paymentMethod'] as String)
        : null,
    hostNotes: json['hostNotes'] as String?,
    proofNotes: json['proofNotes'] as String?,
    proofImageUrl: json['proofImageUrl'] as String?,
    submittedAt: _dateTime(json['submittedAt']),
    player: json['player'] is Map
        ? SessionPlayer.fromJson(
            Map<String, dynamic>.from(json['player'] as Map),
          )
        : null,
    session: json['session'] is Map
        ? PaymentSessionSummary.fromJson(
            Map<String, dynamic>.from(json['session'] as Map),
          )
        : null,
  );

  final String id;
  final String playerId;
  final int amount;
  final PaymentStatus status;
  final DateTime createdAt;
  final String? registeredByUserId;
  final PaymentMethod? paymentMethod;
  final String? hostNotes;
  final String? proofNotes;
  final String? proofImageUrl;
  final DateTime? submittedAt;
  final SessionPlayer? player;
  final PaymentSessionSummary? session;

  String? get sessionName => session?.name;

  bool get isBillable =>
      !(session?.isCancelled ?? false) &&
      (player == null ||
          player!.registrationStatus == RegistrationStatus.approved);
}

class PaymentSessionSummary {
  const PaymentSessionSummary({
    required this.id,
    this.name,
    this.startTime,
    this.status,
    this.cancelledAt,
  });

  factory PaymentSessionSummary.fromJson(Map<String, dynamic> json) =>
      PaymentSessionSummary(
        id: json['id'] as String? ?? '',
        name: json['name'] as String?,
        startTime: _dateTime(json['startTime']),
        status: json['status'] as String?,
        cancelledAt: _dateTime(json['cancelledAt']),
      );

  final String id;
  final String? name;
  final DateTime? startTime;
  final String? status;
  final DateTime? cancelledAt;

  bool get isCancelled => status == 'CANCELLED' || cancelledAt != null;
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

enum PaymentReminderType {
  singlePayment,
  aggregate,
  custom;

  factory PaymentReminderType.fromJson(String? value) => switch (value) {
    'AGGREGATE' => aggregate,
    'CUSTOM' => custom,
    _ => singlePayment,
  };

  String toJson() => switch (this) {
    aggregate => 'AGGREGATE',
    custom => 'CUSTOM',
    singlePayment => 'SINGLE_PAYMENT',
  };
}

enum PaymentReminderStatus {
  pending,
  awaitingConfirmation,
  resolved;

  factory PaymentReminderStatus.fromJson(String? value) => switch (value) {
    'AWAITING_CONFIRMATION' => awaitingConfirmation,
    'RESOLVED' => resolved,
    _ => pending,
  };

  String toJson() => switch (this) {
    awaitingConfirmation => 'AWAITING_CONFIRMATION',
    resolved => 'RESOLVED',
    pending => 'PENDING',
  };
}

class PaymentReminderUser {
  const PaymentReminderUser({
    required this.id,
    required this.name,
    this.email,
    this.image,
    this.gender,
  });

  factory PaymentReminderUser.fromJson(Map<String, dynamic> json) =>
      PaymentReminderUser(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String?,
        image: json['image'] as String?,
        gender: json['gender'] as String?,
      );

  final String id;
  final String name;
  final String? email;
  final String? image;
  final String? gender;
}

class PaymentReminderSession {
  const PaymentReminderSession({
    required this.id,
    required this.name,
  });

  factory PaymentReminderSession.fromJson(Map<String, dynamic> json) =>
      PaymentReminderSession(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );

  final String id;
  final String name;
}

class PaymentReminderLinkedPayment {
  const PaymentReminderLinkedPayment({
    required this.id,
    required this.status,
    required this.amount,
    this.proofImageUrl,
    this.proofNotes,
    this.hostNotes,
    this.sessionId,
  });

  factory PaymentReminderLinkedPayment.fromJson(Map<String, dynamic> json) =>
      PaymentReminderLinkedPayment(
        id: json['id'] as String? ?? '',
        status: PaymentStatus.fromJson(json['status'] as String? ?? 'PENDING'),
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        proofImageUrl: json['proofImageUrl'] as String?,
        proofNotes: json['proofNotes'] as String?,
        hostNotes: json['hostNotes'] as String?,
        sessionId: json['sessionId'] as String?,
      );

  final String id;
  final PaymentStatus status;
  final int amount;
  final String? proofImageUrl;
  final String? proofNotes;
  final String? hostNotes;
  final String? sessionId;
}

class PaymentReminder {
  const PaymentReminder({
    required this.id,
    this.type = PaymentReminderType.singlePayment,
    this.creatorId = '',
    this.recipientId = '',
    this.sessionId,
    this.amount = 0,
    this.note,
    this.status = PaymentReminderStatus.pending,
    required this.reminderCount,
    this.lastRemindedAt,
    this.resolvedAt,
    this.proofImageUrl,
    this.proofNotes,
    this.createdAt,
    this.updatedAt,
    this.creator,
    this.recipient,
    this.session,
    this.linkedPayments = const [],
    List<String>? paymentIds,
  }) : _explicitPaymentIds = paymentIds;

  factory PaymentReminder.fromJson(Map<String, dynamic> json) {
    final rawPayments = (json['payments'] as List<dynamic>? ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map((item) => item['payment'])
        .whereType<Map<Object?, Object?>>()
        .map(
          (p) => PaymentReminderLinkedPayment.fromJson(
            Map<String, dynamic>.from(p),
          ),
        )
        .toList(growable: false);

    return PaymentReminder(
      id: json['id'] as String? ?? '',
      type: PaymentReminderType.fromJson(json['type'] as String?),
      creatorId: json['creatorId'] as String? ?? '',
      recipientId: json['recipientId'] as String? ?? '',
      sessionId: json['sessionId'] as String?,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
      status: PaymentReminderStatus.fromJson(json['status'] as String?),
      reminderCount: (json['reminderCount'] as num?)?.toInt() ?? 0,
      lastRemindedAt: _dateTime(json['lastRemindedAt']),
      resolvedAt: _dateTime(json['resolvedAt']),
      proofImageUrl: json['proofImageUrl'] as String?,
      proofNotes: json['proofNotes'] as String?,
      createdAt: _dateTime(json['createdAt']),
      updatedAt: _dateTime(json['updatedAt']),
      creator: json['creator'] is Map
          ? PaymentReminderUser.fromJson(
              Map<String, dynamic>.from(json['creator'] as Map),
            )
          : null,
      recipient: json['recipient'] is Map
          ? PaymentReminderUser.fromJson(
              Map<String, dynamic>.from(json['recipient'] as Map),
            )
          : null,
      session: json['session'] is Map
          ? PaymentReminderSession.fromJson(
              Map<String, dynamic>.from(json['session'] as Map),
            )
          : null,
      linkedPayments: rawPayments,
    );
  }

  final String id;
  final PaymentReminderType type;
  final String creatorId;
  final String recipientId;
  final String? sessionId;
  final int amount;
  final String? note;
  final PaymentReminderStatus status;
  final int reminderCount;
  final DateTime? lastRemindedAt;
  final DateTime? resolvedAt;
  final String? proofImageUrl;
  final String? proofNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final PaymentReminderUser? creator;
  final PaymentReminderUser? recipient;
  final PaymentReminderSession? session;
  final List<PaymentReminderLinkedPayment> linkedPayments;
  final List<String>? _explicitPaymentIds;

  List<String> get paymentIds =>
      _explicitPaymentIds ??
      linkedPayments.map((p) => p.id).where((id) => id.isNotEmpty).toList();
}

class VietnamBank {
  const VietnamBank({
    required this.code,
    required this.name,
    required this.shortName,
    this.logo,
  });

  factory VietnamBank.fromJson(Map<String, dynamic> json) => VietnamBank(
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    shortName:
        json['shortName'] as String? ?? json['short_name'] as String? ?? '',
    logo: json['logo'] as String?,
  );

  final String code;
  final String name;
  final String shortName;
  final String? logo;
}

class FeeRecalculationResult {
  const FeeRecalculationResult({required this.updated});

  factory FeeRecalculationResult.fromJson(Map<String, dynamic> json) =>
      FeeRecalculationResult(updated: (json['updated'] as num?)?.toInt() ?? 0);

  final int updated;
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
    this.averageRating,
    this.totalRatings,
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
        averageRating: (json['averageRating'] as num?)?.toDouble(),
        totalRatings: (json['totalRatings'] as num?)?.toInt(),
      );

  final String userId;
  final String userName;
  final String? userImage;
  final int totalSessions;
  final int totalAmount;
  final int paidAmount;
  final int pendingAmount;
  final double? averageRating;
  final int? totalRatings;
}

enum HostFinanceGranularity {
  day,
  week,
  month;

  factory HostFinanceGranularity.fromJson(String? value) => switch (value) {
    'day' => day,
    'week' => week,
    _ => month,
  };

  String get wireValue => name;
}

@immutable
class HostFinanceQuery {
  const HostFinanceQuery({
    required this.from,
    required this.to,
    required this.granularity,
  });

  final DateTime from;
  final DateTime to;
  final HostFinanceGranularity granularity;

  Map<String, dynamic> toQueryParameters() => {
    'from': from.toUtc().toIso8601String(),
    'to': to.toUtc().toIso8601String(),
    'granularity': granularity.wireValue,
  };

  @override
  bool operator ==(Object other) =>
      other is HostFinanceQuery &&
      other.from == from &&
      other.to == to &&
      other.granularity == granularity;

  @override
  int get hashCode => Object.hash(from, to, granularity);
}

class HostFinanceMoney {
  const HostFinanceMoney({
    required this.income,
    required this.collected,
    required this.outstanding,
    required this.expenses,
    required this.netActual,
    required this.netExpected,
  });

  factory HostFinanceMoney.fromJson(Map<String, dynamic> json) =>
      HostFinanceMoney(
        income: _int(json['income']),
        collected: _int(json['collected']),
        outstanding: _int(json['outstanding']),
        expenses: _int(json['expenses']),
        netActual: _int(json['netActual']),
        netExpected: _int(json['netExpected']),
      );

  final int income;
  final int collected;
  final int outstanding;
  final int expenses;
  final int netActual;
  final int netExpected;
}

class HostFinanceTotals extends HostFinanceMoney {
  const HostFinanceTotals({
    required super.income,
    required super.collected,
    required super.outstanding,
    required super.expenses,
    required super.netActual,
    required super.netExpected,
    required this.sessionCount,
    required this.playerCount,
    required this.paymentCount,
  });

  factory HostFinanceTotals.fromJson(Map<String, dynamic> json) =>
      HostFinanceTotals(
        income: _int(json['income']),
        collected: _int(json['collected']),
        outstanding: _int(json['outstanding']),
        expenses: _int(json['expenses']),
        netActual: _int(json['netActual']),
        netExpected: _int(json['netExpected']),
        sessionCount: _int(json['sessionCount']),
        playerCount: _int(json['playerCount']),
        paymentCount: _int(json['paymentCount']),
      );

  final int sessionCount;
  final int playerCount;
  final int paymentCount;
}

class HostFinancePreviousTotals extends HostFinanceMoney {
  const HostFinancePreviousTotals({
    required super.income,
    required super.collected,
    required super.outstanding,
    required super.expenses,
    required super.netActual,
    required super.netExpected,
    required this.from,
    required this.to,
  });

  factory HostFinancePreviousTotals.fromJson(Map<String, dynamic> json) =>
      HostFinancePreviousTotals(
        income: _int(json['income']),
        collected: _int(json['collected']),
        outstanding: _int(json['outstanding']),
        expenses: _int(json['expenses']),
        netActual: _int(json['netActual']),
        netExpected: _int(json['netExpected']),
        from: _dateTime(json['from']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        to: _dateTime(json['to']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  final DateTime from;
  final DateTime to;
}

class HostFinanceSeriesPoint {
  const HostFinanceSeriesPoint({
    required this.bucket,
    required this.income,
    required this.collected,
    required this.outstanding,
    required this.expenses,
    required this.netActual,
  });

  factory HostFinanceSeriesPoint.fromJson(Map<String, dynamic> json) =>
      HostFinanceSeriesPoint(
        bucket:
            _dateTime(json['bucket']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        income: _int(json['income']),
        collected: _int(json['collected']),
        outstanding: _int(json['outstanding']),
        expenses: _int(json['expenses']),
        netActual: _int(json['netActual']),
      );

  final DateTime bucket;
  final int income;
  final int collected;
  final int outstanding;
  final int expenses;
  final int netActual;
}

class HostFinanceSessionRow {
  const HostFinanceSessionRow({
    required this.sessionId,
    required this.name,
    required this.playerCount,
    required this.income,
    required this.collected,
    required this.outstanding,
    required this.expenses,
    required this.netActual,
    this.slug,
    this.startTime,
  });

  factory HostFinanceSessionRow.fromJson(Map<String, dynamic> json) =>
      HostFinanceSessionRow(
        sessionId: json['sessionId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String?,
        startTime: _dateTime(json['startTime']),
        playerCount: _int(json['playerCount']),
        income: _int(json['income']),
        collected: _int(json['collected']),
        outstanding: _int(json['outstanding']),
        expenses: _int(json['expenses']),
        netActual: _int(json['netActual']),
      );

  final String sessionId;
  final String name;
  final String? slug;
  final DateTime? startTime;
  final int playerCount;
  final int income;
  final int collected;
  final int outstanding;
  final int expenses;
  final int netActual;
}

class HostFinanceRange {
  const HostFinanceRange({
    required this.from,
    required this.to,
    required this.granularity,
  });

  factory HostFinanceRange.fromJson(Map<String, dynamic> json) =>
      HostFinanceRange(
        from: _dateTime(json['from']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        to: _dateTime(json['to']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        granularity: HostFinanceGranularity.fromJson(
          json['granularity'] as String?,
        ),
      );

  final DateTime from;
  final DateTime to;
  final HostFinanceGranularity granularity;
}

class HostFinanceReport {
  const HostFinanceReport({
    required this.range,
    required this.totals,
    required this.previous,
    required this.series,
    required this.bySession,
    required this.byPlayer,
  });

  factory HostFinanceReport.fromJson(Map<String, dynamic> json) =>
      HostFinanceReport(
        range: HostFinanceRange.fromJson(_map(json['range'])),
        totals: HostFinanceTotals.fromJson(_map(json['totals'])),
        previous: HostFinancePreviousTotals.fromJson(_map(json['previous'])),
        series: _list(json['series'], HostFinanceSeriesPoint.fromJson),
        bySession: _list(json['bySession'], HostFinanceSessionRow.fromJson),
        byPlayer: _list(json['byPlayer'], HostTransactionSummary.fromJson),
      );

  final HostFinanceRange range;
  final HostFinanceTotals totals;
  final HostFinancePreviousTotals previous;
  final List<HostFinanceSeriesPoint> series;
  final List<HostFinanceSessionRow> bySession;
  final List<HostTransactionSummary> byPlayer;
}

DateTime? _dateTime(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;
int _int(dynamic value) => (value as num?)?.toInt() ?? 0;
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) =>
    value is List
    ? value
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false)
    : const [];
