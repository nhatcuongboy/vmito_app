import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vmito_app/features/chat/domain/chat_mode.dart';

part 'chat_contact.freezed.dart';
part 'chat_contact.g.dart';

/// One row of `GET /chat/contacts`.
@freezed
abstract class ChatContact with _$ChatContact {
  const factory ChatContact({
    required String id,
    required String name,
    required ChatMode chatMode,
    String? image,
  }) = _ChatContact;

  factory ChatContact.fromJson(Map<String, dynamic> json) =>
      _$ChatContactFromJson(json);
}
