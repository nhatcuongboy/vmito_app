import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/application/player/host_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_host_detail_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _host = SessionHost(id: 'h1', name: 'Admin');

Session _session({
  SessionHost? host = _host,
  String? hostId,
  String? hostPhone = '0901234567',
  bool allowZaloContact = true,
  bool isCrawled = false,
}) => Session(
  id: 's1',
  name: 'Kèo test',
  status: SessionStatus.preparing,
  host: host,
  hostId: hostId,
  hostName: 'Admin',
  hostPhone: hostPhone,
  allowZaloContact: allowZaloContact,
  isCrawled: isCrawled,
);

const _stats = HostDetailStats(
  averageRating: 4.6,
  totalRatings: 23,
  hostedSessions: 42,
  openSessions: 3,
);

Future<void> _open(
  WidgetTester tester, {
  required Session session,
  Future<HostDetailStats>? stats,
}) async {
  tester.view
    ..physicalSize = const Size(390 * 3, 1400 * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hostDetailStatsProvider.overrideWith(
          (ref, id) => stats ?? Future.value(_stats),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showSessionHostDetailSheet(context, session: session),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pump();
}

void main() {
  testWidgets('shows host name, counts and rating', (tester) async {
    await _open(tester, session: _session());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-host-detail-sheet')), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Sessions Hosted'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Open Sessions'), findsOneWidget);
    expect(find.text('4.6'), findsOneWidget);
    expect(find.text('Based on 23 ratings'), findsOneWidget);
    expect(find.byKey(const Key('host-detail-trusted-badge')), findsOneWidget);
    expect(find.byKey(const Key('host-detail-view-profile')), findsOneWidget);
  });

  testWidgets('hides the trusted badge below 4.5', (tester) async {
    await _open(
      tester,
      session: _session(),
      stats: Future.value(
        const HostDetailStats(
          averageRating: 4.4,
          totalRatings: 5,
          hostedSessions: 1,
          openSessions: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4.4'), findsOneWidget);
    expect(find.byKey(const Key('host-detail-trusted-badge')), findsNothing);
  });

  testWidgets('shows the empty state when the host has no ratings', (
    tester,
  ) async {
    await _open(
      tester,
      session: _session(),
      stats: Future.value(
        const HostDetailStats(
          averageRating: 0,
          totalRatings: 0,
          hostedSessions: 2,
          openSessions: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No ratings yet'), findsOneWidget);
    expect(find.byKey(const Key('host-detail-trusted-badge')), findsNothing);
    // Counters still render — the rating call is independent of them.
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('holds the counters back until the stats resolve', (
    tester,
  ) async {
    final pending = Completer<HostDetailStats>();
    await _open(tester, session: _session(), stats: pending.future);
    await tester.pump();

    expect(find.text('Sessions Hosted'), findsNothing);
    expect(find.text('Based on 23 ratings'), findsNothing);

    pending.complete(_stats);
    await tester.pumpAndSettle();

    expect(find.text('Sessions Hosted'), findsOneWidget);
  });

  testWidgets('gates the contact buttons on phone and Zalo consent', (
    tester,
  ) async {
    await _open(tester, session: _session(allowZaloContact: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('host-detail-call')), findsOneWidget);
    expect(find.byKey(const Key('host-detail-zalo')), findsNothing);
  });

  testWidgets('drops both contact buttons when the host has no phone', (
    tester,
  ) async {
    await _open(tester, session: _session(hostPhone: null));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('host-detail-call')), findsNothing);
    expect(find.byKey(const Key('host-detail-zalo')), findsNothing);
  });

  testWidgets('does not open for a crawled session', (tester) async {
    await _open(tester, session: _session(isCrawled: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-host-detail-sheet')), findsNothing);
  });

  testWidgets('falls back to the flat hostId when host is absent', (
    tester,
  ) async {
    await _open(tester, session: _session(host: null, hostId: 'h2'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-host-detail-sheet')), findsOneWidget);
  });
}
