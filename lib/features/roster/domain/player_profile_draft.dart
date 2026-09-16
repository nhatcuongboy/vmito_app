import 'package:vmito_app/features/roster/domain/player_profile.dart';
import 'package:vmito_app/features/session/domain/host_player.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class CreatePlayerProfileDraft {
  const CreatePlayerProfileDraft({
    required this.name,
    this.gender,
    this.phone,
    this.level,
    this.notes,
    this.clubId,
  });

  final String name;
  final Gender? gender;
  final String? phone;
  final int? level;
  final String? notes;
  final String? clubId;

  Map<String, dynamic> toJson() {
    final cleanPhone = phone?.trim();
    final cleanNotes = notes?.trim();
    final cleanClubId = clubId?.trim();
    return {
      'name': name.trim(),
      if (gender != null) 'gender': gender!.wireValue,
      if (cleanPhone != null && cleanPhone.isNotEmpty) 'phone': cleanPhone,
      if (level != null) 'level': level,
      if (cleanNotes != null && cleanNotes.isNotEmpty) 'notes': cleanNotes,
      if (cleanClubId != null && cleanClubId.isNotEmpty) 'clubId': cleanClubId,
    };
  }
}

class UpdatePlayerProfileDraft {
  const UpdatePlayerProfileDraft({
    this.name,
    this.gender,
    this.phone,
    this.level,
    this.notes,
    this.clubId,
    this.status,
  });

  final String? name;
  final Gender? gender;
  final String? phone;
  final int? level;
  final String? notes;
  final String? clubId;
  final PlayerProfileStatus? status;

  Map<String, dynamic> toJson() {
    final cleanPhone = phone?.trim();
    final cleanNotes = notes?.trim();
    final cleanClubId = clubId?.trim();
    return {
      if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
      if (gender != null) 'gender': gender!.wireValue,
      if (phone != null)
        'phone': cleanPhone?.isEmpty == true ? null : cleanPhone,
      if (level != null) 'level': level,
      if (notes != null)
        'notes': cleanNotes?.isEmpty == true ? null : cleanNotes,
      if (clubId != null)
        'clubId': cleanClubId?.isEmpty == true ? null : cleanClubId,
      if (status != null) 'status': status!.wireValue,
    };
  }
}

class PromoteProfileDraft {
  const PromoteProfileDraft({
    required this.email,
    required this.password,
    this.name,
  });

  final String email;
  final String password;
  final String? name;

  Map<String, dynamic> toJson() {
    final cleanName = name?.trim();
    return {
      'email': email.trim().toLowerCase(),
      'password': password,
      if (cleanName != null && cleanName.isNotEmpty) 'name': cleanName,
    };
  }
}
