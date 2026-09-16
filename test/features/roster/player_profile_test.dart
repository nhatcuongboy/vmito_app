import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/roster/domain/host_recent_player.dart';
import 'package:vmito_app/features/roster/domain/player_profile.dart';
import 'package:vmito_app/features/roster/domain/player_profile_draft.dart';
import 'package:vmito_app/features/roster/domain/player_profile_stats.dart';
import 'package:vmito_app/shared/models/session_player.dart';

void main() {
  group('PlayerProfile', () {
    test('parses ACTIVE personal profile correctly', () {
      final json = {
        'id': 'p1',
        'name': 'Nguyen Van A',
        'gender': 'male',
        'phone': '0901234567',
        'level': 5,
        'clubId': null,
        'userId': null,
        'status': 'ACTIVE',
        'createdAt': '2026-09-01T08:00:00.000Z',
        'totalSessions': 12,
        'notes': 'Plays twice a week',
      };

      final profile = PlayerProfile.fromJson(json);

      expect(profile.id, 'p1');
      expect(profile.name, 'Nguyen Van A');
      expect(profile.gender, Gender.male);
      expect(profile.phone, '0901234567');
      expect(profile.level, 5);
      expect(profile.clubId, isNull);
      expect(profile.club, isNull);
      expect(profile.linkedUserId, isNull);
      expect(profile.status, PlayerProfileStatus.active);
      expect(profile.isActive, isTrue);
      expect(profile.isPromoted, isFalse);
      expect(profile.isArchived, isFalse);
      expect(profile.totalSessions, 12);
      expect(profile.notes, 'Plays twice a week');
    });

    test('parses PROMOTED club member profile correctly', () {
      final json = {
        'id': 'p2',
        'name': 'Tran Thi B',
        'gender': 'female',
        'phone': '0912345678',
        'level': 3,
        'clubId': 'c1',
        'club': {'id': 'c1', 'name': 'Vmito Badminton Club'},
        'userId': 'u100',
        'status': 'PROMOTED',
        'totalSessions': 5,
      };

      final profile = PlayerProfile.fromJson(json);

      expect(profile.id, 'p2');
      expect(profile.name, 'Tran Thi B');
      expect(profile.gender, Gender.female);
      expect(profile.clubId, 'c1');
      expect(profile.club?.name, 'Vmito Badminton Club');
      expect(profile.linkedUserId, 'u100');
      expect(profile.status, PlayerProfileStatus.promoted);
      expect(profile.isPromoted, isTrue);
      expect(profile.isActive, isFalse);
    });

    test('defaults to ACTIVE when status is missing or unknown', () {
      final json = {
        'id': 'p3',
        'name': 'Unknown Status',
      };

      final profile = PlayerProfile.fromJson(json);
      expect(profile.status, PlayerProfileStatus.active);
      expect(profile.isActive, isTrue);
    });
  });

  group('PlayerProfileDraft', () {
    test('CreatePlayerProfileDraft generates correct JSON payload', () {
      const draft = CreatePlayerProfileDraft(
        name: 'Le Van C',
        gender: Gender.male,
        phone: '0987654321',
        level: 4,
        clubId: 'c2',
        notes: 'Intermediate player',
      );

      final json = draft.toJson();

      expect(json['name'], 'Le Van C');
      expect(json['gender'], 'MALE');
      expect(json['phone'], '0987654321');
      expect(json['level'], 4);
      expect(json['clubId'], 'c2');
      expect(json['notes'], 'Intermediate player');
    });

    test('UpdatePlayerProfileDraft omits null fields', () {
      const draft = UpdatePlayerProfileDraft(
        name: 'Le Van C Updated',
        level: 6,
      );

      final json = draft.toJson();

      expect(json['name'], 'Le Van C Updated');
      expect(json['level'], 6);
      expect(json.containsKey('phone'), isFalse);
      expect(json.containsKey('clubId'), isFalse);
    });

    test('PromoteProfileDraft generates correct credentials payload', () {
      const draft = PromoteProfileDraft(
        email: 'user@vmito.com',
        password: 'password123',
        name: 'Le Van C',
      );

      final json = draft.toJson();

      expect(json['email'], 'user@vmito.com');
      expect(json['password'], 'password123');
      expect(json['name'], 'Le Van C');
    });
  });

  group('HostRecentPlayer', () {
    test('parses host recent player correctly', () {
      final json = {
        'profileId': 'p10',
        'userId': 'u10',
        'name': 'Hoang D',
        'gender': 'male',
        'phone': '0933333333',
        'level': 7,
        'clubId': 'c1',
        'club': {'id': 'c1', 'name': 'Shuttle Club'},
        'totalSessions': 8,
        'lastPlayedAt': '2026-09-10T10:00:00.000Z',
      };

      final player = HostRecentPlayer.fromJson(json);

      expect(player.profileId, 'p10');
      expect(player.userId, 'u10');
      expect(player.name, 'Hoang D');
      expect(player.gender, Gender.male);
      expect(player.phone, '0933333333');
      expect(player.level, 7);
      expect(player.totalSessions, 8);
      expect(player.club?.name, 'Shuttle Club');
      expect(player.lastPlayedAt, isNotNull);
    });
  });

  group('PlayerProfileStats', () {
    test('parses stats with session history and badminton points', () {
      final json = {
        'id': 'p1',
        'name': 'Nguyen Van A',
        'gender': 'male',
        'level': 5,
        'winRate': 75.0,
        'totalSessions': 10,
        'totalMatches': 24,
        'wins': 18,
        'losses': 6,
        'draws': 0,
        'pointsStates': [
          {
            'sport': 'BADMINTON',
            'tier': 'GOLD',
            'totalPoints': 1250,
          },
        ],
        'sessionHistory': [
          {
            'sessionId': 's1',
            'sessionName': 'Kèo tối thứ 5',
            'startTime': '2026-09-12T19:00:00.000Z',
            'status': 'FINISHED',
            'wins': 3,
            'losses': 1,
            'draws': 0,
          },
        ],
      };

      final stats = PlayerProfileStats.fromJson(json);

      expect(stats.profileId, 'p1');
      expect(stats.name, 'Nguyen Van A');
      expect(stats.winRate, 75.0);
      expect(stats.totalSessions, 10);
      expect(stats.totalMatches, 24);
      expect(stats.wins, 18);
      expect(stats.losses, 6);
      expect(stats.badmintonPoints?.tier, 'GOLD');
      expect(stats.badmintonPoints?.totalPoints, 1250);
      expect(stats.sessionHistory.length, 1);
      expect(stats.sessionHistory.first.sessionName, 'Kèo tối thứ 5');
      expect(stats.sessionHistory.first.wins, 3);
      expect(stats.sessionHistory.first.losses, 1);
    });
  });
}
