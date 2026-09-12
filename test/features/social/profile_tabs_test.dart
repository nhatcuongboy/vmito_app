import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/social/domain/profile_tabs.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/features/social/presentation/public_profile_screen.dart';
import 'package:vmito_app/features/social/presentation/widgets/profile_header_geometry.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

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
      expect(result.tier, RankingTier.gold);
      expect(result.ranks.single.rank, 4);
      expect(result.stats.wins, 8);
      expect(result.recentTransactions.single.points, 15);
    });

    test('parses complete tier, progress, stats, and transaction data', () {
      final value = UserAchievements.fromJson({
        'sport': 'BADMINTON',
        'totalPoints': 1750,
        'hostPoints': 80,
        'tier': 'GOLD',
        'nextTier': {'nextTier': 'PLATINUM', 'pointsToNext': 2250},
        'ranks': [
          {'period': 'week', 'rank': 3, 'points': 90},
        ],
        'stats': {
          'wins': 8,
          'draws': 2,
          'losses': 4,
          'matchesPlayed': 14,
          'sessionsPlayed': 6,
          'sessionsHosted': 1,
          'tournamentTitles': 2,
          'tournamentRunnerUps': 1,
        },
        'recentTransactions': [
          {
            'id': 'tx-1',
            'points': 20,
            'reason': 'TOURNAMENT_MATCH_WIN',
            'refType': 'TOURNAMENT_MATCH',
            'refId': 'match-1',
            'occurredAt': '2026-08-20T10:00:00.000Z',
          },
        ],
      });

      expect(value.sport, 'BADMINTON');
      expect(value.hostPoints, 80);
      expect(value.nextTier?.tier, RankingTier.platinum);
      expect(value.nextTier?.pointsToNext, 2250);
      expect(value.stats.sessionsPlayed, 6);
      expect(value.stats.sessionsHosted, 1);
      expect(value.recentTransactions.single.refId, 'match-1');
    });

    test('uses safe defaults and keeps absent periods absent', () {
      final value = UserAchievements.fromJson(const {});

      expect(value.sport, 'BADMINTON');
      expect(value.totalPoints, 0);
      expect(value.hostPoints, 0);
      expect(value.tier, RankingTier.bronze);
      expect(value.nextTier, isNull);
      expect(value.ranks, isEmpty);
      expect(value.stats.matchesPlayed, 0);
      expect(value.recentTransactions, isEmpty);
      expect(value.ranks.any((rank) => rank.period == 'all'), isFalse);
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

  testWidgets('profile tab labels follow the active locale', (tester) async {
    late AppLocalizations vietnamese;
    late AppLocalizations english;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            vietnamese = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(publicProfileTabLabels(vietnamese), [
      'Bài viết',
      'Thành tích',
      'Kèo đã host',
      'Nhóm',
      'Đánh giá',
    ]);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            english = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(publicProfileTabLabels(english), [
      'Posts',
      'Achievements',
      'Hosted sessions',
      'Groups',
      'Reviews',
    ]);
  });
}
