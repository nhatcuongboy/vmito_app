import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/social/domain/club.dart';

void main() {
  test('ClubSummary parses expanded public detail payload', () {
    final club = ClubSummary.fromJson({
      'id': 'c1',
      'slug': 'club-a',
      'name': 'CLB A',
      'memberCount': 2,
      'joinPolicy': 'OPEN',
      'image': 'cover.jpg',
      'images': ['gallery.jpg'],
      'host': {'id': 'u1', 'name': 'Host', 'image': 'host.jpg'},
      'socialLinks': {'facebook': 'https://facebook.com/a'},
      'members': [
        {
          'id': 'm1',
          'userId': 'u1',
          'role': 'ADMIN',
          'createdAt': '2026-08-20T10:00:00.000Z',
          'user': {'name': 'Host'},
        },
      ],
      'scheduleVenues': [
        {'id': 'v1', 'name': 'Sân A', 'newAddress': 'Địa chỉ mới'},
      ],
    });

    expect(club.gallery, ['cover.jpg', 'gallery.jpg']);
    expect(club.hostId, 'u1');
    expect(club.members.single.name, 'Host');
    expect(club.members.single.createdAt, DateTime.utc(2026, 8, 20, 10));
    expect(club.scheduleVenues.single.id, 'v1');
    expect(club.socialLinks['facebook'], contains('facebook.com'));
  });

  test('ClubMember tolerates missing or invalid joined dates', () {
    final missing = ClubMember.fromJson({
      'id': 'm1',
      'userId': 'u1',
      'user': {'name': 'Member'},
    });
    final invalid = ClubMember.fromJson({
      'id': 'm2',
      'userId': 'u2',
      'createdAt': 'not-a-date',
      'user': {'name': 'Member 2'},
    });

    expect(missing.createdAt, isNull);
    expect(invalid.createdAt, isNull);
  });

  test('ClubSummary parses membership and operational fields', () {
    final club = ClubSummary.fromJson({
      'id': 'c2',
      'name': 'Nhóm Thành viên',
      'memberCount': 12,
      'joinPolicy': 'APPROVAL_REQUIRED',
      'role': 'MODERATOR',
      'joinedAt': '2026-08-20T10:00:00.000Z',
      'color': '#16A34A',
      'operationalStatus': 'ACTIVE',
    });

    expect(club.role, 'MODERATOR');
    expect(club.joinedAt, DateTime.utc(2026, 8, 20, 10));
    expect(club.color, '#16A34A');
    expect(club.operationalStatus, 'ACTIVE');
  });

  test('ClubSummary gallery ignores empty image URLs', () {
    final club = ClubSummary.fromJson({
      'id': 'c3',
      'name': 'Nhóm ảnh lỗi',
      'memberCount': 1,
      'joinPolicy': 'OPEN',
      'image': '  cover.jpg  ',
      'images': ['', '  ', 'gallery.jpg', 'cover.jpg'],
    });

    expect(club.gallery, ['cover.jpg', 'gallery.jpg']);
  });

  test('ClubJoinRequest parses outgoing club context', () {
    final request = ClubJoinRequest.fromJson({
      'id': 'r1',
      'clubId': 'c1',
      'userId': 'u1',
      'status': 'PENDING',
      'sessionsPlayedCount': 3,
      'createdAt': '2026-08-20T10:00:00.000Z',
      'user': {'name': 'Cường', 'email': 'cuong@example.com'},
      'club': {
        'id': 'c1',
        'slug': 'nhom-a',
        'name': 'Nhóm A',
        'host': {'id': 'host-1', 'name': 'Chủ nhóm'},
      },
    });

    expect(request.clubId, 'c1');
    expect(request.club?.slug, 'nhom-a');
    expect(request.club?.hostName, 'Chủ nhóm');
    expect(request.sessionsPlayedCount, 3);
  });

  test('fee and monthly member payloads preserve all fields', () {
    final fee = ClubFeeConfig.fromJson({
      'id': 'fee-1',
      'maleFeeMonthly': 500000,
      'femaleFeeMonthly': 400000,
      'maleFeePerSession': 80000,
      'femaleFeePerSession': 70000,
    });
    final member = ClubMonthlyMember.fromJson({
      'id': 'fixed-1',
      'userId': 'u1',
      'user': {
        'name': 'Lan',
        'email': 'lan@example.com',
        'gender': 'FEMALE',
      },
    });

    expect(fee.maleFeeMonthly, 500000);
    expect(fee.femaleFeePerSession, 70000);
    expect(member.name, 'Lan');
    expect(member.gender, 'FEMALE');
  });
}
