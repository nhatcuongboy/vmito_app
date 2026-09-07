import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/tournament/data/tournament_schedule_preferences.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_schedule.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_schedule_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TournamentService extends Mock implements TournamentService {}

class _AuthController extends AuthController {
  _AuthController(this.initial);

  final AuthState initial;

  @override
  AuthState build() => initial;
}

class _Preferences implements TournamentSchedulePreferences {
  @override
  Future<bool> readShowPlayerNames() async => false;

  @override
  Future<void> writeShowPlayerNames({required bool value}) async {}
}

class _ScheduleDraft extends Fake implements TournamentScheduleUpdateDraft {}

void main() {
  setUpAll(() => registerFallbackValue(_ScheduleDraft()));

  testWidgets('renders list and mobile agenda at 390x844 without overflow', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final service = _service();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tournament-schedule-list')), findsOneWidget);
    expect(find.text('Team One'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.calendar_view_week_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tournament-schedule-agenda')), findsOneWidget);
    expect(find.text('Sân 1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders hour by court calendar grid at 900x1000', (
    tester,
  ) async {
    _setSize(tester, const Size(900, 1000));
    final service = _service();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_view_week_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tournament-schedule-grid')), findsOneWidget);
    expect(find.text('Sân 1'), findsWidgets);
    expect(find.textContaining(':00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters accents and card opens localized details', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final service = _service();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'team one');
    await tester.pump();
    expect(find.text('Team One'), findsOneWidget);
    await tester.tap(find.text('Team One'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết trận đấu'), findsOneWidget);
    expect(find.text('Trọng tài'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('host sees management actions while feature remains route-free', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final service = _service(host: true);
    const host = User(
      id: 'host-1',
      email: 'host@example.com',
      role: UserRole.host,
    );
    await tester.pumpWidget(
      _app(
        service,
        auth: const AuthState(status: AuthStatus.authenticated, user: host),
        onOpenReferee: (_, _) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Team One'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa lịch'), findsOneWidget);
    expect(find.text('Nhập kết quả'), findsOneWidget);
    expect(find.text('Mở chấm điểm'), findsOneWidget);
    expect(find.text('Xóa trận'), findsOneWidget);

    await tester.tap(find.text('Xóa trận'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa trận đấu?'), findsOneWidget);
    expect(find.text('Trận đấu này sẽ bị xóa vĩnh viễn.'), findsOneWidget);
  });

  testWidgets('result form blocks an incomplete Best-of score', (tester) async {
    _setSize(tester, const Size(390, 844));
    final service = _service(host: true);
    const host = User(
      id: 'host-1',
      email: 'host@example.com',
      role: UserRole.host,
    );
    await tester.pumpWidget(
      _app(
        service,
        auth: const AuthState(status: AuthStatus.authenticated, user: host),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Team One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập kết quả'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    expect(
      find.text('Điểm các set chưa đủ để kết thúc trận'),
      findsOneWidget,
    );
  });

  testWidgets('schedule form stays busy and prevents duplicate submit', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final pending = Completer<void>();
    final service = _service(host: true, scheduleUpdate: pending);
    const host = User(
      id: 'host-1',
      email: 'host@example.com',
      role: UserRole.host,
    );
    await tester.pumpWidget(
      _app(
        service,
        auth: const AuthState(status: AuthStatus.authenticated, user: host),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sửa lịch'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lưu'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Lưu'), findsNothing);
    verify(() => service.updateMatchSchedule(any())).called(1);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Đã cập nhật lịch'), findsOneWidget);
  });

  testWidgets('empty and required-data error states remain refreshable', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app(_service(matches: const [])));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có trận đấu'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(_app(_service(throwMatches: true)));
    await tester.pumpAndSettle();
    expect(find.text('Đã có lỗi xảy ra. Vui lòng thử lại.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('OBS link maps zh locale to cn and copies the court URL', (
    tester,
  ) async {
    _setSize(tester, const Size(900, 1000));
    final service = _service(host: true);
    const host = User(
      id: 'host-1',
      email: 'host@example.com',
      role: UserRole.host,
    );
    await tester.pumpWidget(
      _app(
        service,
        locale: const Locale('zh'),
        auth: const AuthState(status: AuthStatus.authenticated, user: host),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.cast));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('/cn/tournament/t1/overlay/court/1'),
      findsOneWidget,
    );
    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
            }
            return null;
          });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    expect(copiedText, contains('/cn/tournament/t1/overlay/court/1'));
  });
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  TournamentService service, {
  AuthState auth = const AuthState(status: AuthStatus.unauthenticated),
  TournamentRefereeOpener? onOpenReferee,
  Locale locale = const Locale('vi'),
}) => ProviderScope(
  overrides: [
    tournamentServiceProvider.overrideWithValue(service),
    tournamentSchedulePreferencesProvider.overrideWithValue(_Preferences()),
    authControllerProvider.overrideWith(() => _AuthController(auth)),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TournamentScheduleScreen(
      idOrSlug: 'open',
      onOpenReferee: onOpenReferee,
    ),
  ),
);

TournamentService _service({
  bool host = false,
  List<TournamentMatch>? matches,
  bool throwMatches = false,
  Completer<void>? scheduleUpdate,
}) {
  final service = _TournamentService();
  when(() => service.detail('open')).thenAnswer((_) async => _tournament());
  if (throwMatches) {
    when(() => service.matches('t1')).thenThrow(Exception('matches down'));
  } else {
    when(
      () => service.matches('t1'),
    ).thenAnswer((_) async => matches ?? [_match()]);
  }
  when(() => service.courts('t1')).thenAnswer(
    (_) async => const [TournamentCourt(id: 'court-1', number: 1)],
  );
  when(() => service.categoryGroups('c1')).thenAnswer((_) async => const []);
  if (host) {
    when(() => service.umpires('t1')).thenAnswer((_) async => const []);
    when(() => service.ownAssignments('t1')).thenAnswer((_) async => const []);
    if (scheduleUpdate != null) {
      when(
        () => service.updateMatchCode('m1', 'A-01'),
      ).thenAnswer((_) async {});
      when(
        () => service.updateMatchSchedule(any()),
      ).thenAnswer((_) => scheduleUpdate.future);
    }
  }
  return service;
}

TournamentDetail _tournament() => TournamentDetail(
  id: 't1',
  slug: 'open',
  name: 'Open',
  startDate: DateTime(2026, 8, 27),
  endDate: DateTime(2026, 8, 28),
  hostId: 'host-1',
  status: TournamentStatus.finished,
  isPublished: true,
  categories: const [
    TournamentCategory(
      id: 'c1',
      name: 'Open doubles',
      type: 'OPEN_DOUBLES',
      registrationMode: TournamentRegistrationMode.team,
      format: TournamentCategoryFormat.roundRobin,
      registrationCount: 2,
      matchFormat: 'BEST_OF_3',
      teamSize: 2,
    ),
  ],
  venues: const [],
  playerCount: 4,
  pairCount: 2,
);

TournamentMatch _match() => TournamentMatch(
  id: 'm1',
  categoryId: 'c1',
  groupId: 'g1',
  round: 'GROUP',
  matchNumber: 1,
  matchCode: 'A-01',
  status: TournamentMatchStatus.scheduled,
  startTime: DateTime(2026, 8, 27, 9),
  courtId: 'court-1',
  court: const TournamentCourt(id: 'court-1', number: 1),
  participants: const [
    TournamentMatchParticipant(
      position: 1,
      registrationId: 'r1',
      registration: TournamentRegistration(id: 'r1', pairName: 'Team One'),
    ),
    TournamentMatchParticipant(
      position: 2,
      registrationId: 'r2',
      registration: TournamentRegistration(id: 'r2', pairName: 'Team Two'),
    ),
  ],
);
