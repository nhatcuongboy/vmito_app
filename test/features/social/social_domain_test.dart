import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';

void main() {
  test('parses a feed post with counts, images and original post', () {
    final post = SocialPost.fromJson({
      'id': 'p1',
      'content': 'Kèo tối nay rất vui',
      'author': {'id': 'u1', 'name': 'An'},
      'images': [
        {'id': 'i2', 'url': 'https://example.com/2.png', 'order': 2},
        {'id': 'i1', 'url': 'https://example.com/1.png', 'order': 1},
      ],
      '_count': {'likes': 5, 'comments': 3, 'shares': 2},
      'isLiked': true,
      'createdAt': '2026-07-30T10:00:00.000Z',
      'originalPost': {
        'id': 'p0',
        'content': 'Bài gốc',
        'author': {'id': 'u2', 'name': 'Bình'},
        'images': <Object>[],
        '_count': <String, Object>{},
        'createdAt': '2026-07-29T10:00:00.000Z',
      },
    });

    expect(post.author.name, 'An');
    expect(post.images.map((image) => image.id), ['i1', 'i2']);
    expect(post.likeCount, 5);
    expect(post.isLiked, isTrue);
    expect(post.originalPost?.content, 'Bài gốc');
  });

  test('parses club venue, schedule and pagination contract', () {
    final page = ClubPage.fromJson({
      'items': [
        {
          'id': 'c1',
          'name': 'Vmito Gò Vấp',
          'memberCount': 24,
          'joinPolicy': 'OPEN',
          'defaultVenue': {
            'name': 'Sân A',
            'address': 'Gò Vấp',
            'lat': 10.8,
            'lng': 106.7,
          },
          'schedules': [
            {'dayOfWeek': 5, 'startTime': '19:00', 'endTime': '21:00'},
          ],
        },
      ],
      'page': 2,
      'totalPages': 4,
    });

    expect(page.page, 2);
    expect(page.totalPages, 4);
    expect(page.clubs.single.defaultVenue?.hasCoordinates, isTrue);
    expect(page.clubs.single.schedules.single.dayOfWeek, 5);
  });

  test('parses public rating values from numeric JSON', () {
    final stats = RatingStats.fromJson({
      'averageRating': 4,
      'totalRatings': 12.0,
    });

    expect(stats.average, 4.0);
    expect(stats.total, 12);
  });

  test('rating eligibility keeps only backend-authorized targets', () {
    final eligibility = RatingEligibility.fromJson({
      'canRateHost': true,
      'canRatePlayers': ['u2', 'u3'],
      'ratedPlayerIds': ['u4'],
    });

    expect(eligibility.canRateHost, isTrue);
    expect(eligibility.canRatePlayers, ['u2', 'u3']);
    expect(eligibility.isEmpty, isFalse);
  });

  test('club draft trims values and keeps explicit clears for editing', () {
    const draft = ClubDraft(
      name: '  Vmito Quận 7  ',
      description: '  ',
      location: '',
      joinPolicy: 'APPROVAL_REQUIRED',
      isPublic: true,
    );

    expect(draft.toJson(), {
      'name': 'Vmito Quận 7',
      'description': '',
      'location': '',
      'joinPolicy': 'APPROVAL_REQUIRED',
      'isPublic': true,
      'maxMembers': null,
    });
  });

  test('parses club management member, request and announcement', () {
    final member = ClubMember.fromJson({
      'id': 'm1',
      'userId': 'u1',
      'role': 'MODERATOR',
      'user': {
        'id': 'u1',
        'name': 'An',
        'email': 'an@vmito.com',
        'level': 4.0,
      },
    });
    final request = ClubJoinRequest.fromJson({
      'id': 'r1',
      'userId': 'u2',
      'message': 'Cho mình tham gia',
      'createdAt': '2026-07-30T10:00:00.000Z',
      'user': {'name': 'Bình', 'email': 'binh@vmito.com'},
    });
    final announcement = ClubAnnouncement.fromJson({
      'id': 'a1',
      'title': 'Đổi sân',
      'content': 'Tuần này chuyển sang sân B',
      'createdAt': '2026-07-30T10:00:00.000Z',
      'pinnedUntil': '2026-08-30T10:00:00.000Z',
      'author': {'name': 'Admin'},
    });

    expect(member.role, 'MODERATOR');
    expect(member.level, 4);
    expect(request.userName, 'Bình');
    expect(request.message, 'Cho mình tham gia');
    expect(announcement.authorName, 'Admin');
    expect(announcement.pinnedUntil, isNotNull);
  });
}
