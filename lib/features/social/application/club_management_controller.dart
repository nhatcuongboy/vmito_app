import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/session/data/session_form_service.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/club_user_option.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

final hostFeatureAccessProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  if (user.role == UserRole.host || user.role == UserRole.admin) return true;
  if (user.role != UserRole.player && user.role != UserRole.referee) {
    return false;
  }
  final flags = await ref.watch(sessionFeatureFlagsProvider.future);
  return flags['PLAYER_VIP_ENABLED'] == true;
});

final managedClubsProvider = FutureProvider<List<ClubSummary>>((ref) async {
  if (!await ref.watch(hostFeatureAccessProvider.future)) return const [];
  return ref.watch(socialServiceProvider).managedClubs();
});

final myClubsProvider = FutureProvider<List<ClubSummary>>(
  (ref) => ref.watch(socialServiceProvider).myClubs(),
);

final myClubRequestsProvider = FutureProvider<List<ClubJoinRequest>>(
  (ref) async => (await ref.watch(socialServiceProvider).myClubRequests())
      .where((request) => request.status == 'PENDING')
      .toList(growable: false),
);

final incomingClubRequestsProvider = FutureProvider<List<ClubJoinRequest>>(
  (ref) async {
    if (!await ref.watch(hostFeatureAccessProvider.future)) return const [];
    final admin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    return (await ref
            .watch(socialServiceProvider)
            .managedClubJoinRequests(admin: admin))
        .where((request) => request.status == 'PENDING')
        .toList(growable: false);
  },
);

final pendingClubsProvider = FutureProvider<List<ClubSummary>>((ref) async {
  if (!(ref.watch(currentUserProvider)?.isAdmin ?? false)) return const [];
  return ref.watch(socialServiceProvider).pendingClubs();
});

final canCreateClubProvider = Provider<bool>((ref) {
  return ref.watch(hostFeatureAccessProvider).asData?.value ?? false;
});

List<ClubSummary> memberOnlyClubs(
  List<ClubSummary> clubs, {
  required String? currentUserId,
}) {
  final unique = <String, ClubSummary>{};
  for (final club in clubs) {
    final current = unique[club.id];
    if (current == null || club.role == 'ADMIN') unique[club.id] = club;
  }
  return unique.values
      .where(
        (club) => club.role != 'ADMIN' && club.hostUserId != currentUserId,
      )
      .toList(growable: false);
}

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

typedef ClubFeePeriod = ({String clubId, int year, int month});

// Family providers keep the inferred generic shape at call sites.
// ignore: specify_nonobvious_property_types
final clubFeeProvider = FutureProvider.family<ClubFeeConfig?, ClubFeePeriod>(
  (ref, period) => ref
      .watch(socialServiceProvider)
      .clubFeeForMonth(period.clubId, period.year, period.month),
);

// Family providers keep the inferred generic shape at call sites.
// ignore: specify_nonobvious_property_types
final clubMonthlyMembersProvider =
    FutureProvider.family<List<ClubMonthlyMember>, ClubFeePeriod>(
      (ref, period) => ref
          .watch(socialServiceProvider)
          .clubMonthlyMembers(period.clubId, period.year, period.month),
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

// Search providers keep debounced remote lookups out of the form widget.
// ignore: specify_nonobvious_property_types
final clubVenueSearchProvider = FutureProvider.family<List<Venue>, String>(
  (ref, query) async {
    final result = await ref
        .read(venueServiceProvider)
        .browse(
          VenueFilter(keyword: query, sortBy: 'relevance'),
          page: 1,
          limit: 50,
        );
    return result.venues;
  },
);

// Search providers keep the admin-only user lookup out of the form widget.
// ignore: specify_nonobvious_property_types
final clubHostUsersProvider =
    FutureProvider.family<List<ClubHostUserOption>, String>(
      (ref, query) => ref.read(socialServiceProvider).searchHostUsers(query),
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
        ..invalidate(myClubsProvider)
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
        ..invalidate(myClubsProvider)
        ..invalidate(clubsControllerProvider);
    },
  );

  Future<void> cancelJoinRequest(String clubId) => _mutate(
    () => _service.cancelClubJoinRequest(clubId),
    invalidate: () => ref.invalidate(myClubRequestsProvider),
  );

  Future<void> approveClub(String clubId) => _mutate(
    () => _service.approveClub(clubId),
    invalidate: () {
      ref
        ..invalidate(pendingClubsProvider)
        ..invalidate(managedClubsProvider)
        ..invalidate(clubsControllerProvider);
    },
  );

  Future<void> rejectClub(String clubId, String reason) => _mutate(
    () => _service.rejectClub(clubId, reason),
    invalidate: () {
      ref
        ..invalidate(pendingClubsProvider)
        ..invalidate(managedClubsProvider);
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
        ..invalidate(incomingClubRequestsProvider)
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
    invalidate: () {
      ref
        ..invalidate(clubJoinRequestsProvider(clubId))
        ..invalidate(incomingClubRequestsProvider);
    },
  );

  Future<void> saveClubFee(
    ClubFeePeriod period, {
    int? maleFeeMonthly,
    int? femaleFeeMonthly,
    int? maleFeePerSession,
    int? femaleFeePerSession,
  }) => _mutate(
    () => _service.saveClubFee(
      period.clubId,
      year: period.year,
      month: period.month,
      maleFeeMonthly: maleFeeMonthly,
      femaleFeeMonthly: femaleFeeMonthly,
      maleFeePerSession: maleFeePerSession,
      femaleFeePerSession: femaleFeePerSession,
    ),
    invalidate: () => ref.invalidate(clubFeeProvider(period)),
  );

  Future<void> addMonthlyMember(
    ClubFeePeriod period,
    String userId,
  ) => _mutate(
    () => _service.addClubMonthlyMember(
      period.clubId,
      userId: userId,
      year: period.year,
      month: period.month,
    ),
    invalidate: () => ref.invalidate(clubMonthlyMembersProvider(period)),
  );

  Future<void> removeMonthlyMember(
    ClubFeePeriod period,
    String userId,
  ) => _mutate(
    () => _service.removeClubMonthlyMember(
      period.clubId,
      userId: userId,
      year: period.year,
      month: period.month,
    ),
    invalidate: () => ref.invalidate(clubMonthlyMembersProvider(period)),
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
