import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_request.freezed.dart';
part 'chat_request.g.dart';

/// The sender profile embedded in a [ChatRequest] — deliberately not the
/// shared `User` model: the backend only exposes id/name/image here.
@freezed
abstract class ChatRequestSender with _$ChatRequestSender {
  const factory ChatRequestSender({
    required String id,
    required String name,
    String? image,
  }) = _ChatRequestSender;

  factory ChatRequestSender.fromJson(Map<String, dynamic> json) =>
      _$ChatRequestSenderFromJson(json);
}

/// One row of `GET /chat/requests` — an incoming, still-pending chat request.
///
/// No message preview is included by design: the backend never surfaces
/// message bodies outside Stream. See `vmito-be/src/chat/chat.service.ts#getRequests`.
@freezed
abstract class ChatRequest with _$ChatRequest {
  const factory ChatRequest({
    required String id,
    required ChatRequestSender sender,
    required DateTime createdAt,
  }) = _ChatRequest;

  factory ChatRequest.fromJson(Map<String, dynamic> json) =>
      _$ChatRequestFromJson(json);
}
