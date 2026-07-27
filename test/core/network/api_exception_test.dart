import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/api_exception.dart';

/// Every body below was captured verbatim from the live backend at
/// `http://localhost:3001/api`. If the backend's error shape changes, these
/// tests are what will catch it.
DioException _responseError(int status, Map<String, dynamic> body) {
  final options = RequestOptions(path: '/auth/login');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: body,
    ),
  );
}

void main() {
  group('message extraction', () {
    test('reads the nested error.message from HttpExceptionFilter', () {
      // POST /auth/login with wrong credentials.
      final error = ApiException.fromDio(
        _responseError(401, {
          'success': false,
          'error': {
            'message': 'Invalid credentials',
            'error': 'Unauthorized',
            'statusCode': 401,
          },
          'statusCode': 401,
          'timestamp': '2026-07-27T17:08:18.283Z',
        }),
      );

      // Regression: reading a top-level `message` found nothing here, so every
      // backend error fell back to a generic string and the sign-in screen
      // could never show "Invalid credentials".
      expect(error.message, 'Invalid credentials');
      expect(error.kind, ApiErrorKind.unauthorized);
      expect(error.isUnauthorized, isTrue);
    });

    test('joins class-validator failures so no field is hidden', () {
      // POST /auth/login with an empty body.
      final error = ApiException.fromDio(
        _responseError(400, {
          'success': false,
          'error': {
            'message': [
              'email should not be empty',
              'email must be an email',
              'password should not be empty',
              'password must be a string',
            ],
            'error': 'Bad Request',
            'statusCode': 400,
          },
          'statusCode': 400,
        }),
      );

      expect(error.kind, ApiErrorKind.validation);
      expect(error.message, contains('email must be an email'));
      expect(error.message, contains('password should not be empty'));
    });

    test('falls back to a bare {message} body', () {
      // Anything not routed through HttpExceptionFilter — a proxy, or a plain
      // Nest default response.
      final error = ApiException.fromDio(
        _responseError(404, {'message': 'Session not found'}),
      );

      expect(error.message, 'Session not found');
      expect(error.kind, ApiErrorKind.notFound);
    });

    test('falls back to the kind default when the body carries no text', () {
      final error = ApiException.fromDio(_responseError(500, {}));

      expect(error.kind, ApiErrorKind.server);
      expect(error.message, ApiErrorKind.server.defaultMessage);
      expect(error.isRetryable, isTrue);
    });
  });

  group('classification', () {
    test('maps transport failures without a response', () {
      final options = RequestOptions(path: '/sessions');

      expect(
        ApiException.fromDio(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        ).kind,
        ApiErrorKind.network,
      );

      expect(
        ApiException.fromDio(
          DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          ),
        ).kind,
        ApiErrorKind.timeout,
      );
    });

    test('cancellation is not retryable', () {
      final error = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/sessions'),
          type: DioExceptionType.cancel,
        ),
      );

      expect(error.kind, ApiErrorKind.cancelled);
      expect(error.isRetryable, isFalse);
    });
  });
}
