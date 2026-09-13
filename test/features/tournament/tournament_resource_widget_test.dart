import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/data/tournament_management_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_player_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_sponsor_service.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_player_import_editor.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_players_panel.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_sponsor_editor.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _Players extends Mock implements TournamentPlayerService {}

class _Sponsors extends Mock implements TournamentSponsorService {}

class _Access extends Mock implements TournamentManagementService {}

void main() {
  late _Players players;
  late _Sponsors sponsors;
  late _Access access;
  setUpAll(() => registerFallbackValue(const SponsorDraft(name: '')));
  setUp(() {
    players = _Players();
    sponsors = _Sponsors();
    access = _Access();
    when(() => players.list('t')).thenAnswer(
      (_) async => [
        const TournamentPlayer(id: 'p', name: 'An', code: 'A1'),
        const TournamentPlayer(id: 'q', name: 'Chi', userId: 'u'),
      ],
    );
    when(() => sponsors.list('t')).thenAnswer((_) async => []);
    when(() => access.access('t')).thenAnswer(
      (_) async => const TournamentMyAccess(
        tournamentId: 't',
        isHost: true,
        isAdmin: false,
        permissions: {},
      ),
    );
  });
  Widget app(Widget home) => ProviderScope(
    overrides: [
      tournamentPlayerServiceProvider.overrideWithValue(players),
      tournamentSponsorServiceProvider.overrideWithValue(sponsors),
      tournamentManagementServiceProvider.overrideWithValue(access),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: home),
    ),
  );

  testWidgets(
    'sponsor form validates after submit and prevents duplicate save',
    (tester) async {
      final pending = Completer<TournamentSponsor>();
      when(() => sponsors.save('t', any())).thenAnswer((_) => pending.future);
      await tester.pumpWidget(
        app(const TournamentSponsorEditor(tournamentId: 't')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Name is required'), findsNothing);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      verifyNever(() => sponsors.save('t', any()));
      final name = find.byWidgetPredicate(
        (w) =>
            w is ReactiveTextField<String> &&
            w.formControlName == ResourceControl.name,
      );
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Brand');
      await tester.pump();
      expect(find.text('Name is required'), findsNothing);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
      verify(() => sponsors.save('t', any())).called(1);
      await tester.pumpWidget(const SizedBox());
      pending.complete(const TournamentSponsor(id: 's', name: 'Brand'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone player filter, search, and delete cancellation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(const TournamentPlayersPanel(tournamentId: 't')),
    );
    await tester.pumpAndSettle();
    expect(find.text('An'), findsOneWidget);
    await tester.tap(find.text('Linked to an account'));
    await tester.pumpAndSettle();
    expect(find.text('An'), findsNothing);
    expect(find.text('Chi'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => players.delete('q'));
    await tester.enterText(find.byType(TextField), 'not found');
    await tester.pumpAndSettle();
    expect(find.text('No matching records'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'text import requires valid preview and invalidates stale preview',
    (tester) async {
      await tester.pumpWidget(
        app(const TournamentPlayerImportEditor(tournamentId: 't')),
      );
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'A1,Other,invalid');
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Duplicate code'), findsOneWidget);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(find.byType(TextField), ',New Player,Nam');
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.enterText(find.byType(TextField), ',');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
