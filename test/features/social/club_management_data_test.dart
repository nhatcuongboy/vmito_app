import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';

ClubSummary club(
  String id, {
  String role = 'MEMBER',
  String? hostId,
}) => ClubSummary(
  id: id,
  name: id,
  memberCount: 1,
  joinPolicy: 'OPEN',
  role: role,
  hostId: hostId,
);

void main() {
  test('memberOnlyClubs deduplicates and excludes managed clubs', () {
    final result = memberOnlyClubs(
      [
        club('member'),
        club('managed-role', role: 'ADMIN'),
        club('managed-host', hostId: 'me'),
        club('duplicate'),
        club('duplicate', role: 'MODERATOR'),
      ],
      currentUserId: 'me',
    );

    expect(result.map((item) => item.id), ['member', 'duplicate']);
  });
}
