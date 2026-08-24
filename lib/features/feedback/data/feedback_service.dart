import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/feedback/domain/feedback.dart';

class FeedbackService {
  const FeedbackService(this._client);

  final ApiClient _client;

  Future<List<FeedbackItem>> listMine() async {
    final response = await _client.get<dynamic>(ApiEndpoints.feedback);
    return unwrapList(response.data, FeedbackItem.fromJson);
  }

  Future<FeedbackAttachment> uploadImage({
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.feedbackUploadImage,
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, FeedbackAttachment.fromJson);
  }

  Future<FeedbackItem> create(FeedbackDraft draft) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.feedback,
      data: draft.toJson(),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, FeedbackItem.fromJson);
  }
}

final feedbackServiceProvider = Provider<FeedbackService>(
  (ref) => FeedbackService(ref.watch(apiClientProvider)),
);
