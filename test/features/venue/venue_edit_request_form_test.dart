import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/venue/domain/form/venue_edit_request_form.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

void main() {
  const venue = Venue(
    id: 'venue-1',
    name: 'Sân A',
    address: 'Địa chỉ đầy đủ',
    streetAddress: '12 Nguyễn Huệ',
    newCity: 'Hồ Chí Minh',
    newDistrict: 'Phường Sài Gòn',
    sportTypes: ['BADMINTON', 'PICKLEBALL'],
    openingHours: '6:00 – 22:30',
    phone: '090 123 4567',
  );

  test('uses the complete venue defaults and builds the wire payload', () {
    final form = createVenueEditRequestForm(venue);
    addTearDown(form.dispose);

    expect(form.control(VenueEditRequestControl.street).value, '12 Nguyễn Huệ');
    expect(
      form.control(VenueEditRequestControl.sportTypes).value,
      {'BADMINTON', 'PICKLEBALL'},
    );

    final payload = venueEditRequestDraftFromForm(form).toJson();
    expect(payload['openingHours'], '06:00 - 22:30');
    expect(payload['phone'], '0901234567');
    expect(payload.containsKey('note'), isFalse);
  });

  test('validates trimmed required fields and a positive court count', () {
    final form = createVenueEditRequestForm(venue);
    addTearDown(form.dispose);

    form.control(VenueEditRequestControl.name).value = ' ';
    form.control(VenueEditRequestControl.street).value = 'ab';
    form.control(VenueEditRequestControl.numberOfCourts).value = 0;

    expect(form.control(VenueEditRequestControl.name).invalid, isTrue);
    expect(form.control(VenueEditRequestControl.street).invalid, isTrue);
    expect(
      form.control(VenueEditRequestControl.numberOfCourts).invalid,
      isTrue,
    );
  });

  test('formats partial opening hours with web-compatible defaults', () {
    expect(
      formatVenueOpeningHours(const Duration(hours: 6), null),
      '06:00 - 23:59',
    );
    expect(
      formatVenueOpeningHours(null, const Duration(hours: 22)),
      '00:00 - 22:00',
    );
    expect(formatVenueOpeningHours(null, null), isNull);
  });

  test('detects and extracts administrative units from a street address', () {
    const address = '123 Nguyễn Văn Trỗi, Phường 8, Quận Phú Nhuận';
    expect(hasAdminUnitsInStreet(address), isTrue);
    expect(extractCleanStreetAddress(address), '123 Nguyễn Văn Trỗi');
    expect(hasAdminUnitsInStreet('123 Nguyễn Văn Trỗi'), isFalse);
  });
}
