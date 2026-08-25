import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/tournament/application/tournament_create_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_create_request.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class _TournamentService extends Mock implements TournamentService {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      TournamentCreateRequest(
        name: 'Fallback',
        sportType: TournamentSportType.badminton,
        startDate: DateTime(2026, 8, 25),
        endDate: DateTime(2026, 8, 25),
      ),
    );
  });

  test(
    'ignores a duplicate submit while the first request is pending',
    () async {
      final service = _TournamentService();
      final completer = Completer<TournamentSummary>();
      when(() => service.create(any())).thenAnswer((_) => completer.future);
      final container = ProviderContainer(
        overrides: [tournamentServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        tournamentCreateControllerProvider.notifier,
      );
      final request = TournamentCreateRequest(
        name: 'Vmito Open',
        sportType: TournamentSportType.badminton,
        startDate: DateTime(2026, 8, 25),
        endDate: DateTime(2026, 8, 25),
      );

      final first = controller.submit(request);
      final second = await controller.submit(request);
      expect(second, isNull);
      completer.complete(
        TournamentSummary(
          id: 't1',
          name: 'Vmito Open',
          startDate: DateTime(2026, 8, 25),
          endDate: DateTime(2026, 8, 25),
          status: TournamentStatus.preparing,
          isPublished: false,
        ),
      );
      expect((await first)?.id, 't1');
      verify(() => service.create(any())).called(1);
    },
  );
}
