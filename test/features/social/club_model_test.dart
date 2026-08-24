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
    expect(club.scheduleVenues.single.id, 'v1');
    expect(club.socialLinks['facebook'], contains('facebook.com'));
  });
}
