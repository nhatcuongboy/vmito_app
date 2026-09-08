import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_overview_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

void main() {
  const session = Session(
    id: 'overview-1',
    name: 'Kèo tối thứ Sáu',
    status: SessionStatus.inProgress,
    numberOfCourts: 2,
    maxPlayersPerCourt: 4,
    location: 'Gò Vấp',
    players: [
      SessionPlayer(
        id: 'p1',
        name: 'Sơn',
        gender: Gender.male,
      ),
      SessionPlayer(
        id: 'p2',
        name: 'Minh',
        gender: Gender.female,
        status: PlayerStatus.playing,
      ),
      SessionPlayer(
        id: 'p3',
        name: 'Nam',
        gender: Gender.male,
        status: PlayerStatus.ready,
      ),
    ],
  );

  Widget app(Session value, {VoidCallback? onEdit}) => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HostOverviewTab(session: value, onEdit: onEdit),
      ),
    ),
  );

  testWidgets('shows session information and the four web overview stats', (
    tester,
  ) async {
    await tester.pumpWidget(app(session));

    expect(find.text('Thông tin kèo'), findsOneWidget);
    expect(find.text('Gò Vấp'), findsOneWidget);
    expect(find.text('Thống kê kèo'), findsOneWidget);
    expect(find.text('Người chơi'), findsOneWidget);
    expect(find.text('Chờ'), findsOneWidget);
    expect(find.text('Đang chơi'), findsOneWidget);
    expect(find.text('Sẵn sàng'), findsOneWidget);
    expect(find.text('3/8'), findsOneWidget);
  });

  testWidgets('expands long descriptions and hides the toggle for short ones', (
    tester,
  ) async {
    final short = session.copyWith(description: 'Mô tả ngắn');
    await tester.pumpWidget(app(short));
    expect(
      find.byKey(const Key('host-overview-description-toggle')),
      findsNothing,
    );

    final long = session.copyWith(
      description: List.filled(
        12,
        'Nội dung mô tả dài của buổi chơi.',
      ).join(' '),
    );
    await tester.pumpWidget(app(long));
    expect(find.text('Mở rộng'), findsOneWidget);

    await tester.tap(find.byKey(const Key('host-overview-description-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Thu gọn'), findsOneWidget);
  });

  testWidgets('uses a clear card title and a low-emphasis edit action', (
    tester,
  ) async {
    await tester.pumpWidget(app(session, onEdit: () {}));

    final title = tester.widget<Text>(find.text('Thông tin kèo'));
    expect(title.style?.fontSize, 16);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(
      tester.widget(find.byKey(const Key('host-overview-edit-session'))),
      isA<TextButton>(),
    );
  });

  testWidgets('edit action invokes the shared modal callback', (tester) async {
    var edits = 0;
    await tester.pumpWidget(app(session, onEdit: () => edits++));

    await tester.tap(find.byKey(const Key('host-overview-edit-session')));

    expect(edits, 1);
  });

  testWidgets('shows every unique level in rank order and fixed fee per slot', (
    tester,
  ) async {
    final detailed = session.copyWith(
      requiredLevels: const [6, 9, 4, 6],
      feeConfig: const SessionFeeConfig(
        maleFee: 70000,
        femaleFee: 80000,
      ),
    );
    await tester.pumpWidget(app(detailed));

    expect(find.byKey(const ValueKey('host-overview-level-9')), findsOneWidget);
    expect(find.byKey(const ValueKey('host-overview-level-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('host-overview-level-6')), findsOneWidget);
    expect(
      find.textContaining('70k-80k', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('/slot', findRichText: true), findsOneWidget);

    final weak = tester.getTopLeft(find.text('Yếu-'));
    final average = tester.getTopLeft(find.text('TB'));
    final good = tester.getTopLeft(find.text('Khá'));
    expect(weak.dx, lessThan(average.dx));
    expect(average.dx, lessThan(good.dx));

    await tester.tap(find.byKey(const Key('host-overview-fee-info')));
    await tester.pumpAndSettle();
    expect(find.text('Phí tham gia'), findsOneWidget);
  });

  testWidgets('shows all-levels badge and split fee without per-slot suffix', (
    tester,
  ) async {
    final unrestricted = session.copyWith(
      feeConfig: const SessionFeeConfig(feeType: FeeType.splitEvenly),
    );
    await tester.pumpWidget(app(unrestricted));

    expect(find.byKey(const Key('host-overview-all-levels')), findsOneWidget);
    expect(find.text('Tất cả trình độ'), findsOneWidget);
    expect(find.text('Chia đều'), findsOneWidget);
    expect(find.textContaining('/slot', findRichText: true), findsNothing);
  });

  testWidgets(
    'gallery swipes, updates its indicator, and opens current image',
    (
      tester,
    ) async {
      final gallery = session.copyWith(
        coverPhoto: 'https://example.com/cover.jpg',
        images: const [
          'https://example.com/cover.jpg',
          'https://example.com/second.jpg',
        ],
      );
      await tester.pumpWidget(app(gallery));
      await tester.pump();

      Size dotSize(int index) => tester.getSize(
        find.byKey(ValueKey('host-gallery-dot-$index')),
      );

      expect(dotSize(0).width, greaterThan(dotSize(1).width));

      await tester.fling(
        find.byKey(const Key('host-overview-gallery')),
        const Offset(-700, 0),
        1200,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(dotSize(1).width, greaterThan(dotSize(0).width));

      tester
          .widget<GestureDetector>(
            find.byKey(const ValueKey('host-overview-cover-1')),
          )
          .onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('2/2'), findsOneWidget);
    },
  );
}
