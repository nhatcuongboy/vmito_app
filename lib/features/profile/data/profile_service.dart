import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/auth/domain/user.dart';

class ProfileImageAsset {
  const ProfileImageAsset({required this.url, required this.publicId});

  final String url;
  final String publicId;
}

typedef ProfileImageCompressor = Future<Uint8List> Function(Uint8List bytes);

const int _maximumProfileUploadBytes = 5 * 1024 * 1024;

Future<Uint8List> compressProfileImage(Uint8List bytes) async {
  var quality = 90;
  var compressed = bytes;
  do {
    compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1600,
      minHeight: 1600,
      quality: quality,
    );
    quality -= 10;
  } while (compressed.lengthInBytes > _maximumProfileUploadBytes &&
      quality >= 50);
  return compressed;
}

class ProfileService {
  const ProfileService(
    this._client, {
    this.imageCompressor = compressProfileImage,
  });

  final ApiClient _client;
  final ProfileImageCompressor imageCompressor;

  Future<User> user(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.user(id),
      dedup: false,
    );
    return unwrap(response.data, User.fromJson);
  }

  Future<User> updateUser(String id, Map<String, dynamic> data) async {
    final response = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.user(id),
      data: data,
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, User.fromJson);
  }

  Future<ProfileImageAsset> uploadAvatar(
    Uint8List bytes, {
    required String filename,
    required void Function(int progress) onProgress,
  }) => _upload(
    endpoint: ApiEndpoints.uploadAvatar,
    field: 'avatar',
    bytes: bytes,
    filename: filename,
    onProgress: onProgress,
  );

  Future<ProfileImageAsset> uploadCover(
    Uint8List bytes, {
    required String filename,
    required void Function(int progress) onProgress,
  }) => _upload(
    endpoint: ApiEndpoints.uploadCover,
    field: 'cover',
    bytes: bytes,
    filename: filename,
    onProgress: onProgress,
  );

  Future<ProfileImageAsset> _upload({
    required String endpoint,
    required String field,
    required Uint8List bytes,
    required String filename,
    required void Function(int progress) onProgress,
  }) async {
    final compressed = await imageCompressor(bytes);

    if (compressed.lengthInBytes > _maximumProfileUploadBytes) {
      throw const FormatException('Profile image exceeds the upload limit');
    }

    final response = await _client.post<Map<String, dynamic>>(
      endpoint,
      data: FormData.fromMap({
        field: MultipartFile.fromBytes(
          compressed,
          filename: _jpegFilename(filename),
        ),
      }),
      options: apiOptions(skipGlobalError: true),
      onSendProgress: (sent, total) {
        if (total > 0) onProgress(((sent / total) * 100).round().clamp(0, 100));
      },
    );
    final asset = unwrap(
      response.data,
      (json) => ProfileImageAsset(
        url: json['url'] as String? ?? '',
        publicId: json['publicId'] as String? ?? '',
      ),
    );
    if (asset.url.isEmpty || asset.publicId.isEmpty) {
      throw StateError('Profile image upload returned no asset identifier');
    }
    return asset;
  }

  String _jpegFilename(String original) {
    final dot = original.lastIndexOf('.');
    final stem = dot > 0 ? original.substring(0, dot) : original;
    return '${stem.isEmpty ? 'profile' : stem}.jpg';
  }
}

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(ref.watch(apiClientProvider)),
);
