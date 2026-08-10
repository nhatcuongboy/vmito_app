import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/social/domain/profile_tabs.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/features/social/presentation/public_profile_screen.dart';
import 'package:vmito_app/features/social/presentation/widgets/profile_header_geometry.dart';

void main() {
  group('ProfileHeaderGeometry', () {
    test('sizes cover from screen width with tablet clamp', () {
      expect(ProfileHeaderGeometry.coverHeightForWidth(320), 140);
      expect(ProfileHeaderGeometry.coverHeightForWidth(375), 150);
      expect(ProfileHeaderGeometry.coverHeightForWidth(393), 157.2);
      expect(ProfileHeaderGeometry.coverHeightForWidth(430), 172);
      expect(ProfileHeaderGeometry.coverHeightForWidth(600), 190);
    });

    test('maps scrolling directly from responsive cover to toolbar height', () {
      expect(ProfileHeaderGeometry.visibleHeight(-20, 375), 150);
      expect(ProfileHeaderGeometry.visibleHeight(0, 375), 150);
      expect(ProfileHeaderGeometry.visibleHeight(47, 375), 103);
      expect(ProfileHeaderGeometry.visibleHeight(94, 375), 56);
      expect(ProfileHeaderGeometry.visibleHeight(300, 375), 56);
    });

    test('crossfades separate expanded and compact identities', () {
      final extent = ProfileHeaderGeometry.collapseExtent(375);
      expect(ProfileHeaderGeometry.expandedIdentityOpacity(0, 375), 1);
      expect(ProfileHeaderGeometry.compactIdentityOpacity(0, 375), 0);
      expect(
        ProfileHeaderGeometry.expandedIdentityOpacity(extent * .85, 375),
        closeTo(.5, .001),
      );
      expect(ProfileHeaderGeometry.expandedIdentityOpacity(extent, 375), 0);
      expect(ProfileHeaderGeometry.compactIdentityOpacity(extent, 375), 1);
    });

    test('caps centered cover stretch at fifteen percent', () {
      expect(ProfileHeaderGeometry.stretchScale(0, 375), 1);
      expect(ProfileHeaderGeometry.stretchScale(-15, 375), 1.1);
      expect(ProfileHeaderGeometry.stretchScale(-22.5, 375), 1.15);
      expect(ProfileHeaderGeometry.stretchScale(-100, 375), 1.15);
    });
  });

  group('UserAchievements', () {
    test('parses public leaderboard payload with safe defaults', () {
      final result = UserAchievements.fromJson({
        'totalPoints': 420,
        'tier': 'GOLD',
        'ranks': [
          {'period': 'month', 'rank': 4, 'points': 120},
        ],
        'stats': {'wins': 8, 'draws': 2, 'losses': 1, 'matchesPlayed': 11},
        'recentTransactions': [
          {
            'id': 'tx-1',
            'points': 15,
            'reason': 'Thắng kèo',
            'occurredAt': '2026-01-01T10:00:00.000Z',
          },
        ],
      });

      expect(result.totalPoints, 420);
      expect(result.tier, 'GOLD');
      expect(result.ranks.single.rank, 4);
      expect(result.stats.wins, 8);
      expect(result.recentTransactions.single.points, 15);
    });
  });

  test('favorite target chooses nested location as subtitle', () {
    final target = FavoriteTarget.fromJson({
      'id': 'session-1',
      'name': 'Kèo tối',
      'slug': 'keo-toi',
      'coverPhoto': 'https://example.test/cover.jpg',
      'venue': {'name': 'Sân Vmito'},
    });

    expect(target.slug, 'keo-toi');
    expect(target.image, 'https://example.test/cover.jpg');
    expect(target.subtitle, 'Sân Vmito');
  });

  test('profile posts keep feed posts, activities, and reposts', () {
    final page = SocialPostPage.fromJson({
      'posts': [
        {
          'id': 'post-1',
          'content': 'Bài viết',
          'author': {'id': 'user-1', 'name': 'Nhật Cường'},
          'createdAt': '2026-08-11T10:00:00.000Z',
        },
        {
          'id': 'activity-1',
          'content': '',
          'author': {'id': 'user-1', 'name': 'Nhật Cường'},
          'activityType': 'SESSION_CREATED',
          'createdAt': '2026-08-11T09:00:00.000Z',
        },
        {
          'id': 'repost-1',
          'content': '',
          'author': {'id': 'user-1', 'name': 'Nhật Cường'},
          'originalPost': {
            'id': 'original-1',
            'content': 'Bài gốc',
            'author': {'id': 'user-2', 'name': 'Người khác'},
            'createdAt': '2026-08-10T09:00:00.000Z',
          },
          'createdAt': '2026-08-11T08:00:00.000Z',
        },
      ],
      'page': 1,
      'hasMore': false,
    });

    expect(page.posts, hasLength(3));
    expect(page.posts[0].author.id, 'user-1');
    expect(page.posts[1].activityType, 'SESSION_CREATED');
    expect(page.posts[2].originalPost?.id, 'original-1');
  });

  test('favorite tab is only present for the profile owner', () {
    expect(publicProfileTabLabels(isOwner: false), hasLength(5));
    expect(
      publicProfileTabLabels(isOwner: false),
      isNot(contains('Yêu thích')),
    );
    expect(publicProfileTabLabels(isOwner: true), hasLength(6));
    expect(publicProfileTabLabels(isOwner: true).last, 'Yêu thích');
  });
}
