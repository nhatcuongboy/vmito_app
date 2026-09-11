import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/data/session_form_service.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_location_payload.dart';
import 'package:vmito_app/features/session/presentation/player/create_session_screen.dart';
import 'package:vmito_app/features/session/presentation/player/session_edit_modal.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_filter_sheet.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

class _MockSessionFormService extends Mock implements SessionFormService {}

class _MockSessionRepository extends Mock implements SessionRepository {}

class _TestAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: User(id: 'host-1', email: 'host@test.vn', role: UserRole.host),
  );
}

Widget _app({
  Widget home = const CreateSessionScreen(),
  SessionFormService? sessionFormService,
  SessionRepository? sessionRepository,
  bool host = false,
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: [
    if (host) authControllerProvider.overrideWith(_TestAuthController.new),
    if (sessionFormService != null)
      sessionFormServiceProvider.overrideWithValue(sessionFormService),
    if (sessionRepository != null)
      sessionRepositoryProvider.overrideWithValue(sessionRepository),
    ...overrides,
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openAdvanced(WidgetTester tester) async {
  final toggle = find.byKey(const Key('advanced-toggle'));
  await tester.scrollUntilVisible(
    toggle,
    600,
    scrollable: find.byType(Scrollable).first,
  );
  tester.widget<InkWell>(toggle).onTap!();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 220));
}

Future<void> _scrollDownTo(WidgetTester tester, Finder finder) async {
  final scrollable = tester.state<ScrollableState>(
    find.byType(Scrollable).first,
  );
  final position = scrollable.position;
  final target = position.pixels + tester.getCenter(finder).dy - 420;
  position.jumpTo(target.clamp(0, position.maxScrollExtent));
  await tester.pump();
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CreateSessionRequest(
        name: 'Fallback',
        location: CustomLocation(name: 'Fallback court'),
        hostName: 'Host',
        maxPlayersPerCourt: 8,
      ),
    );
  });

  testWidgets('mobile form uses sticky submit and reports required fields', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Thông tin chung'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Thông tin chung')).style?.fontSize,
      16,
    );
    expect(find.byKey(const Key('create-session-ai')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('create-session-ai'))).height,
      48,
    );
    expect(
      find.ancestor(
        of: find.byKey(const Key('create-session-ai')),
        matching: find.byType(AppBar),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('create-session-submit')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('create-session-submit')),
        matching: find.byIcon(AppIcons.add),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('create-session-submit')));
    await tester.pump();
    expect(find.text('Vui lòng nhập tên kèo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI sheet fits when the keyboard is open', (tester) async {
    _setSize(tester, const Size(390, 844));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('create-session-ai')));
    await tester.pump();

    final sheetInput = find.descendant(
      of: find.byKey(const Key('create-session-ai-sheet')),
      matching: find.byType(TextField),
    );
    await tester.pump();

    expect(tester.widget<TextField>(sheetInput).focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected badminton keeps its shuttlecock artwork visible', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    final shuttlecockIcon = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/icons/shuttlecock.png',
    );

    expect(shuttlecockIcon, findsOneWidget);
    expect(tester.widget<Image>(shuttlecockIcon).color, isNull);
  });

  testWidgets('host and single-day time fields match the mobile web grid', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('host-phone-field')),
      400,
      scrollable: scrollable,
    );
    final hostName = tester.getTopLeft(
      find.byKey(const Key('host-name-field')),
    );
    final hostPhone = tester.getTopLeft(
      find.byKey(const Key('host-phone-field')),
    );
    expect(hostName.dy, lessThan(hostPhone.dy));

    await tester.scrollUntilVisible(
      find.byKey(const Key('session-end-picker')),
      400,
      scrollable: scrollable,
    );
    final date = tester.getTopLeft(
      find.byKey(const Key('session-date-picker')),
    );
    final start = tester.getTopLeft(
      find.byKey(const Key('session-start-picker')),
    );
    final end = tester.getTopLeft(find.byKey(const Key('session-end-picker')));
    expect(date.dy, lessThan(start.dy));
    expect(start.dy, end.dy);
    expect(start.dx, lessThan(end.dx));
  });

  testWidgets('single-day time field opens the app wheel picker', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    final startPicker = find.byKey(const Key('session-start-picker'));
    await tester.scrollUntilVisible(
      startPicker,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(startPicker);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-time-picker-sheet')), findsOneWidget);
    expect(find.byKey(const Key('app-time-picker-wheel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom location switch hides and restores the venue picker', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    final toggle = find.byKey(const Key('custom-location-switch'));
    await tester.scrollUntilVisible(
      toggle,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('venue-picker')), findsOneWidget);
    expect(find.byKey(const Key('custom-location-fields')), findsNothing);

    await tester.tap(toggle);
    await tester.pump();
    expect(find.byKey(const Key('venue-picker')), findsNothing);
    expect(find.byKey(const Key('custom-location-fields')), findsOneWidget);
    final customName = find
        .descendant(
          of: find.byKey(const Key('custom-location-fields')),
          matching: find.byType(EditableText),
        )
        .first;
    await tester.enterText(customName, 'Sân tạm của tôi');

    await tester.tap(toggle);
    await tester.pump();
    expect(find.byKey(const Key('venue-picker')), findsOneWidget);
    expect(find.byKey(const Key('custom-location-fields')), findsNothing);

    await tester.tap(toggle);
    await tester.pump();
    expect(
      tester.widget<EditableText>(customName).controller.text,
      'Sân tạm của tôi',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit mode restores custom location and hides AI', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      _app(
        home: const CreateSessionScreen(
          editingSessionId: 's1',
          initialSession: Session(
            id: 's1',
            name: 'Kèo tùy chọn',
            status: SessionStatus.preparing,
            customLocationName: 'Sân tạm',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('create-session-ai')), findsNothing);
    expect(find.byKey(const Key('venue-picker')), findsNothing);
    expect(find.byKey(const Key('custom-location-fields')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone edit modal prefills, locks pending submit, then closes', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final repository = _MockSessionRepository();
    final pending = Completer<Session>();
    final start = DateTime(2030, 8, 26, 18);
    final initial = Session(
      id: 'modal-1',
      name: 'Kèo modal',
      status: SessionStatus.preparing,
      hostName: 'Chủ kèo',
      hostPhone: '0901234567',
      customLocationName: 'Sân modal',
      startTime: start,
      endTime: start.add(const Duration(hours: 2)),
      numberOfCourts: 1,
      maxPlayersPerCourt: 8,
    );
    when(() => repository.update('modal-1', any())).thenAnswer(
      (_) => pending.future,
    );
    Session? result;

    await tester.pumpWidget(
      _app(
        host: true,
        sessionRepository: repository,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showSessionEditModal(context, session: initial);
              },
              child: const Text('Mở chỉnh sửa'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở chỉnh sửa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('session-edit-bottom-sheet')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('session-edit-bottom-sheet'))).height,
      lessThanOrEqualTo(844),
    );
    expect(find.text('Chỉnh sửa kèo'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Chỉnh sửa kèo')).style,
      AppSheetHeader.titleTextStyle(tester.element(find.text('Chỉnh sửa kèo'))),
    );
    expect(find.text('Kèo modal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('create-session-submit')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('create-session-submit')),
          )
          .onPressed,
      isNull,
    );

    final updated = initial.copyWith(name: 'Kèo đã sửa');
    pending.complete(updated);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-edit-bottom-sheet')), findsNothing);
    expect(result, updated);
    verify(() => repository.update('modal-1', any())).called(1);
  });

  testWidgets('tablet edit modal uses a height-constrained dialog', (
    tester,
  ) async {
    _setSize(tester, const Size(1024, 900));
    const initial = Session(
      id: 'tablet-modal',
      name: 'Kèo tablet',
      status: SessionStatus.inProgress,
      hostName: 'Chủ kèo',
      hostPhone: '0901234567',
      customLocationName: 'Sân tablet',
      maxPlayersPerCourt: 8,
    );

    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showSessionEditModal(
                context,
                session: initial,
              ),
              child: const Text('Mở tablet'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở tablet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('session-edit-dialog')), findsOneWidget);
    expect(find.byKey(const Key('session-edit-bottom-sheet')), findsNothing);
    expect(find.text('Kèo tablet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level controls select a band and open descriptions', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    final level = find.byKey(const ValueKey('level-9'));
    await tester.scrollUntilVisible(
      level,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(level);
    await tester.pump();
    expect(
      tester.getSemantics(level).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    final allLevels = find.byKey(const Key('all-levels-option'));
    await tester.tap(allLevels);
    await tester.pump();
    expect(
      tester.getSemantics(allLevels).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(level).flagsCollection.isSelected,
      Tristate.isFalse,
    );

    await tester.tap(find.byKey(const Key('level-info')));
    await tester.pump();
    expect(find.text('Mô tả trình độ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fee switch and chevron preserve entered values', (tester) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    final feeSwitch = find.byKey(const Key('fee-enabled'));
    await tester.scrollUntilVisible(
      feeSwitch,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('fee-fields')).hitTestable(), findsNothing);

    await tester.tap(feeSwitch);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.scrollUntilVisible(
      find.byKey(const Key('male-fee-field')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('fee-fields')), findsOneWidget);

    final maleInput = find.descendant(
      of: find.byKey(const Key('male-fee-field')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(maleInput, '120000');
    await tester.scrollUntilVisible(
      find.byKey(const Key('fee-collapse')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('fee-collapse')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('fee-fields')).hitTestable(), findsNothing);

    await tester.tap(find.byKey(const Key('fee-collapse')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.scrollUntilVisible(
      find.byKey(const Key('male-fee-field')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<EditableText>(maleInput).controller.text,
      '120.000',
    );

    await tester.scrollUntilVisible(
      feeSwitch,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(feeSwitch);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('fee-fields')).hitTestable(), findsNothing);
    await tester.tap(feeSwitch);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.scrollUntilVisible(
      find.byKey(const Key('male-fee-field')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<EditableText>(maleInput).controller.text,
      '120.000',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the redesigned cards do not overflow at 320 logical pixels', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 700));
    await tester.pumpWidget(_app(host: true));
    await tester.pump(const Duration(milliseconds: 100));

    for (final key in const [
      Key('host-phone-field'),
      Key('session-end-picker'),
      Key('level-info'),
      Key('fee-enabled'),
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(key),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'advanced card matches the responsive web layout and keeps data',
    (
      tester,
    ) async {
      _setSize(tester, const Size(600, 844));
      await tester.pumpWidget(_app(host: true));
      await tester.pump(const Duration(milliseconds: 100));
      await _openAdvanced(tester);

      expect(find.byKey(const Key('session-images-empty')), findsOneWidget);
      expect(find.text('Giao diện sân'), findsOneWidget);
      expect(find.text('Thể loại mặc định'), findsOneWidget);
      expect(find.byKey(const ValueKey('court-color-#179a3b')), findsOneWidget);

      final shuttle = find.byKey(const Key('shuttlecock-field'));
      final maxPlayers = find.byKey(const Key('max-players-field'));
      await tester.scrollUntilVisible(
        maxPlayers,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.getTopLeft(shuttle).dy, tester.getTopLeft(maxPlayers).dy);

      final shuttleInput = find.descendant(
        of: shuttle,
        matching: find.byType(EditableText),
      );
      await tester.enterText(shuttleInput, 'Yonex Aerosensa 30');
      final singles = find.byKey(const Key('match-type-singles'));
      final singlesButton = find.descendant(
        of: singles,
        matching: find.byType(OutlinedButton),
      );
      await _scrollDownTo(tester, singlesButton);
      await tester.tap(singlesButton);
      await tester.pump();
      expect(
        tester.getSemantics(singles).flagsCollection.isSelected,
        Tristate.isTrue,
      );

      final advancedToggle = find.byKey(const Key('advanced-toggle'));
      await _scrollDownTo(tester, advancedToggle);
      tester.widget<InkWell>(advancedToggle).onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      tester.widget<InkWell>(advancedToggle).onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      await tester.scrollUntilVisible(
        shuttle,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<EditableText>(shuttleInput).controller.text,
        'Yonex Aerosensa 30',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('advanced fields stack without overflow at 320 pixels', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 700));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));
    await _openAdvanced(tester);

    final shuttle = find.byKey(const Key('shuttlecock-field'));
    final maxPlayers = find.byKey(const Key('max-players-field'));
    await tester.scrollUntilVisible(
      maxPlayers,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.getTopLeft(shuttle).dy,
      lessThan(tester.getTopLeft(maxPlayers).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('account gallery paginates and applies selected images', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final service = _MockSessionFormService();
    when(() => service.getMyImages(page: 1)).thenAnswer(
      (_) async => const pagination.Page<UserImageAsset>(
        items: [
          UserImageAsset(
            id: '1',
            url: 'https://example.test/one.jpg',
            publicId: 'session/one',
          ),
        ],
        total: 2,
        page: 1,
        limit: 20,
        totalPages: 2,
      ),
    );
    when(() => service.getMyImages(page: 2)).thenAnswer(
      (_) async => const pagination.Page<UserImageAsset>(
        items: [
          UserImageAsset(
            id: '2',
            url: 'https://example.test/two.jpg',
            publicId: 'session/two',
          ),
        ],
        total: 2,
        page: 2,
        limit: 20,
        totalPages: 2,
      ),
    );

    await tester.pumpWidget(_app(sessionFormService: service));
    await tester.pump(const Duration(milliseconds: 100));
    await _openAdvanced(tester);
    final openLibrary = find.byKey(
      const Key('open-account-image-library'),
    );
    await _scrollDownTo(tester, openLibrary);
    await tester.tap(openLibrary);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('account-image-session/one')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('account-image-session/one')));
    await tester.tap(find.byKey(const Key('load-more-account-images')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('account-image-session/two')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('account-image-session/two')));
    await tester.tap(find.byKey(const Key('confirm-account-images')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('2/5'), findsOneWidget);
    expect(find.byKey(const Key('session-images-empty')), findsNothing);
    verify(() => service.getMyImages(page: 1)).called(1);
    verify(() => service.getMyImages(page: 2)).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('court rows can be added without overflowing a wide layout', (
    tester,
  ) async {
    _setSize(tester, const Size(1024, 900));

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.scrollUntilVisible(
      find.byKey(const Key('add-court')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('add-court')));
    await tester.pump();

    expect(find.byKey(const ValueKey('court-number-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bulk specific-dates picker adds a date and weekday chips use the '
    'shared filter-chip style',
    (tester) async {
      _setSize(tester, const Size(600, 844));
      await tester.pumpWidget(_app(host: true));
      await tester.pump(const Duration(milliseconds: 100));

      final bulkToggle = find.byKey(const Key('bulk-enabled'));
      await tester.scrollUntilVisible(
        bulkToggle,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      // scrollUntilVisible's own Scrollable.ensureVisible stops as soon as
      // the target's edge clears the viewport, which can leave it directly
      // under the screen's sticky submit bar (a Scaffold overlay the
      // Scrollable doesn't know about). Re-center it so the tap lands on the
      // switch, not the bar.
      await Scrollable.ensureVisible(
        tester.element(bulkToggle),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(bulkToggle);
      await tester.pump();

      final pickDates = find.byKey(const Key('bulk-pick-dates'));
      await tester.scrollUntilVisible(
        pickDates,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(pickDates), alignment: 0.5);
      await tester.pump();
      await tester.tap(pickDates);
      await tester.pumpAndSettle();

      final today = DateTime.now();
      final dayKey = Key(
        'multi-date-picker-day-${today.year}-${today.month}-${today.day}',
      );
      expect(find.byKey(dayKey), findsOneWidget);
      await tester.tap(find.byKey(dayKey));
      await tester.pump();
      await tester.tap(find.byKey(const Key('multi-date-picker-done')));
      await tester.pumpAndSettle();

      expect(
        find.text('${today.day}/${today.month}/${today.year}'),
        findsOneWidget,
      );

      await tester.tap(find.text('Lặp lại theo tuần'));
      await tester.pump();

      final mondayChip = find.byKey(const Key('bulk-weekday-1'));
      await tester.scrollUntilVisible(
        mondayChip,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(mondayChip),
        alignment: 0.5,
      );
      await tester.pump();
      expect(tester.widget<AppFilterChip>(mondayChip).label, 'Thứ 2');
      expect(tester.widget<AppFilterChip>(mondayChip).selected, isFalse);
      await tester.tap(mondayChip);
      await tester.pump();
      expect(tester.widget<AppFilterChip>(mondayChip).selected, isTrue);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bulk toggle and collapse button control visibility of bulk fields',
    (tester) async {
      _setSize(tester, const Size(600, 844));
      await tester.pumpWidget(_app(host: true));
      await tester.pump(const Duration(milliseconds: 100));

      final bulkToggle = find.byKey(const Key('bulk-enabled'));
      await tester.scrollUntilVisible(
        bulkToggle,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(bulkToggle),
        alignment: 0.5,
      );
      await tester.pump();

      expect(find.byKey(const Key('bulk-fields')).hitTestable(), findsNothing);

      await tester.tap(bulkToggle);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('bulk-fields')).hitTestable(), findsOneWidget);

      final bulkCollapse = find.byKey(const Key('bulk-collapse'));
      await tester.tap(bulkCollapse);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('bulk-fields')).hitTestable(), findsNothing);

      await tester.tap(bulkCollapse);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('bulk-fields')).hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'venue picker displays Sân prefix and detailed address sublabel when venue is present',
    (tester) async {
      _setSize(tester, const Size(390, 844));
      const testVenue = Venue(
        id: 'v1',
        name: 'Kỳ Hòa',
        address: '123 Sư Vạn Hạnh, Q.10, TP.HCM',
      );
      await tester.pumpWidget(
        _app(
          overrides: [
            venueDetailProvider('v1').overrideWith((ref) async => testVenue),
          ],
          home: const CreateSessionScreen(
            editingSessionId: 's1',
            initialSession: Session(
              id: 's1',
              name: 'Kèo chiều',
              status: SessionStatus.preparing,
              venue: SessionVenue(
                id: 'v1',
                name: 'Kỳ Hòa',
                address: '123 Sư Vạn Hạnh, Q.10, TP.HCM',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sân Kỳ Hòa'), findsOneWidget);
      expect(find.byKey(const Key('venue-sublabel')), findsOneWidget);
      expect(find.text('123 Sư Vạn Hạnh, Q.10, TP.HCM'), findsOneWidget);
    },
  );

  testWidgets(
    'bulk session section displays real-time session count subtext',
    (tester) async {
      _setSize(tester, const Size(600, 844));
      await tester.pumpWidget(_app(host: true));
      await tester.pump(const Duration(milliseconds: 100));

      final bulkToggle = find.byKey(const Key('bulk-enabled'));
      await tester.scrollUntilVisible(
        bulkToggle,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(bulkToggle),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(bulkToggle);
      await tester.pump(const Duration(milliseconds: 250));

      final countFinder = find.byKey(const Key('bulk-session-count'));
      await tester.scrollUntilVisible(
        countFinder,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(countFinder, findsOneWidget);
      expect(find.text('Số kèo sẽ tạo: 0'), findsOneWidget);

      final pickDates = find.byKey(const Key('bulk-pick-dates'));
      await tester.tap(pickDates);
      await tester.pumpAndSettle();

      final today = DateTime.now();
      final dayKey = Key(
        'multi-date-picker-day-${today.year}-${today.month}-${today.day}',
      );
      await tester.tap(find.byKey(dayKey));
      await tester.pump();
      await tester.tap(find.byKey(const Key('multi-date-picker-done')));
      await tester.pumpAndSettle();

      expect(find.text('Số kèo sẽ tạo: 1'), findsOneWidget);
    },
  );
}
