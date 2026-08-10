import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/social/domain/profile_tabs.dart';
import 'package:vmito_app/features/social/presentation/public_profile_screen.dart';

void main() {
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
