import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/session/application/player/create_session_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/bulk_create_session.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/form/session_form_drafts.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_location_payload.dart';

class _Repository extends Mock implements SessionRepository {}

CreateSessionRequest _request() => const CreateSessionRequest(
  name: 'Kèo tối',
  location: VenueLocation('v1'),
  hostName: 'Cường',
  maxPlayersPerCourt: 8,
  images: ['https://image/1.jpg'],
  imagePublicIds: ['image-1'],
  coverPhoto: 'https://image/1.jpg',
  coverPhotoPublicId: 'image-1',
);

void main() {
  setUpAll(() {
    registerFallbackValue(_request());
    registerFallbackValue(
      BulkCreateSessionRequest(
        mode: BulkCreationMode.specificDates,
        baseSession: _request(),
      ),
    );
  });

  test('bulk create syncs images to sibling sessions', () async {
    final repository = _Repository();
    const sessions = [
      Session(id: 's1', name: 'One', status: SessionStatus.preparing),
      Session(id: 's2', name: 'Two', status: SessionStatus.preparing),
    ];
    when(() => repository.createBulk(any())).thenAnswer(
      (_) async => const BulkCreateSessionResult(
        success: true,
        sessionsCreated: 2,
        sessions: sessions,
      ),
    );
    when(
      () => repository.updateImages(
        any(),
        coverPhoto: any(named: 'coverPhoto'),
        coverPhotoPublicId: any(named: 'coverPhotoPublicId'),
        images: any(named: 'images'),
        imagePublicIds: any(named: 'imagePublicIds'),
      ),
    ).thenAnswer((_) async {});
    final container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(createSessionControllerProvider.notifier)
        .submitBulk(
          BulkCreateSessionRequest(
            mode: BulkCreationMode.specificDates,
            baseSession: _request(),
          ),
        );

    expect(result?.sessionsCreated, 2);
    verify(
      () => repository.updateImages(
        's2',
        coverPhoto: 'https://image/1.jpg',
        coverPhotoPublicId: 'image-1',
        images: const ['https://image/1.jpg'],
        imagePublicIds: const ['image-1'],
      ),
    ).called(1);
  });
}
