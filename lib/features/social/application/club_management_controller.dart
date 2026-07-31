import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';

final managedClubsProvider = FutureProvider<List<ClubSummary>>(
  (ref) => ref.watch(socialServiceProvider).managedClubs(),
);

// See managedClubsProvider for why this family keeps an inferred type.
// ignore: specify_nonobvious_property_types
final managedClubProvider = FutureProvider.family<ClubSummary, String>(
  (ref, clubId) => ref.watch(socialServiceProvider).managedClub(clubId),
);

// See managedClubsProvider for why this family keeps an inferred type.
// ignore: specify_nonobvious_property_types
final clubMembersProvider = FutureProvider.family<List<ClubMember>, String>(
  (ref, clubId) => ref.watch(socialServiceProvider).clubMembers(clubId),
);

// See managedClubsProvider for why this family keeps an inferred type.
// ignore: specify_nonobvious_property_types
final clubJoinRequestsProvider =
    FutureProvider.family<List<ClubJoinRequest>, String>(
      (ref, clubId) =>
          ref.watch(socialServiceProvider).clubJoinRequests(clubId),
    );

// See managedClubsProvider for why this family keeps an inferred type.
// ignore: specify_nonobvious_property_types
final clubAnnouncementsProvider =
    FutureProvider.family<List<ClubAnnouncement>, String>(
      (ref, clubId) =>
          ref.watch(socialServiceProvider).clubAnnouncements(clubId),
    );

typedef ClubUserSearch = ({String clubId, String query});

// See managedClubsProvider for why this family keeps an inferred type.
// ignore: specify_nonobvious_property_types
final clubUserSearchProvider =
    FutureProvider.family<List<ClubUserSearchResult>, ClubUserSearch>(
      (ref, search) => ref
          .watch(socialServiceProvider)
          .searchClubUsers(search.clubId, search.query),
    );

class ClubManagementController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  SocialService get _service => ref.read(socialServiceProvider);

  Future<ClubSummary> saveClub(ClubDraft draft, {String? clubId}) async {
    state = const AsyncLoading();
    try {
      final club = clubId == null
          ? await _service.createClub(draft)
          : await _service.updateClub(clubId, draft);
      state = const AsyncData(null);
      ref
        ..invalidate(managedClubsProvider)
        ..invalidate(clubsControllerProvider)
        ..invalidate(clubDetailProvider(club.id))
        ..invalidate(managedClubProvider(club.id));
      return club;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteClub(String clubId) => _mutate(
    () => _service.deleteClub(clubId),
    invalidate: () {
      ref
        ..invalidate(managedClubsProvider)
        ..invalidate(clubsControllerProvider);
    },
  );

  Future<void> addMember(String clubId, String userId) => _mutate(
    () => _service.addClubMember(clubId, userId),
    invalidate: () => ref.invalidate(clubMembersProvider(clubId)),
  );

  Future<void> removeMember(String clubId, String userId) => _mutate(
    () => _service.removeClubMember(clubId, userId),
    invalidate: () => ref.invalidate(clubMembersProvider(clubId)),
  );

  Future<void> updateMemberRole(
    String clubId,
    String userId,
    String role,
  ) => _mutate(
    () => _service.updateClubMemberRole(clubId, userId, role),
    invalidate: () => ref.invalidate(clubMembersProvider(clubId)),
  );

  Future<void> approveRequest(String clubId, String requestId) => _mutate(
    () => _service.approveClubJoinRequest(clubId, requestId),
    invalidate: () {
      ref
        ..invalidate(clubJoinRequestsProvider(clubId))
        ..invalidate(clubMembersProvider(clubId));
    },
  );

  Future<void> rejectRequest(
    String clubId,
    String requestId, {
    String? response,
  }) => _mutate(
    () => _service.rejectClubJoinRequest(
      clubId,
      requestId,
      response: response,
    ),
    invalidate: () => ref.invalidate(clubJoinRequestsProvider(clubId)),
  );

  Future<void> saveAnnouncement(
    String clubId, {
    String? announcementId,
    required String title,
    required String content,
    DateTime? pinnedUntil,
  }) => _mutate(
    () => _service.saveClubAnnouncement(
      clubId,
      announcementId: announcementId,
      title: title,
      content: content,
      pinnedUntil: pinnedUntil,
    ),
    invalidate: () {
      ref
        ..invalidate(clubAnnouncementsProvider(clubId))
        ..invalidate(clubDetailProvider(clubId));
    },
  );

  Future<void> deleteAnnouncement(String clubId, String announcementId) =>
      _mutate(
        () => _service.deleteClubAnnouncement(clubId, announcementId),
        invalidate: () {
          ref
            ..invalidate(clubAnnouncementsProvider(clubId))
            ..invalidate(clubDetailProvider(clubId));
        },
      );

  Future<void> _mutate(
    Future<void> Function() action, {
    required void Function() invalidate,
  }) async {
    state = const AsyncLoading();
    try {
      await action();
      invalidate();
      state = const AsyncData(null);
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final clubManagementControllerProvider =
    NotifierProvider<ClubManagementController, AsyncValue<void>>(
      ClubManagementController.new,
    );
