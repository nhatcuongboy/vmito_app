import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/utils/logger.dart';

/// App-wide sink for errors no screen chose to handle.
///
/// The web app calls a toaster directly from the axios interceptor. That is
/// not available below the widget tree here, so failures are published and the
/// app shell renders them — see `AppErrorListener`.
class ApiErrorBus {
  final _controller = StreamController<ApiException>.broadcast();

  Stream<ApiException> get stream => _controller.stream;

  void publish(ApiException error) {
    if (!_controller.isClosed) _controller.add(error);
  }

  void dispose() => _controller.close();
}

final apiErrorBusProvider = Provider<ApiErrorBus>((ref) {
  final bus = ApiErrorBus();
  ref.onDispose(bus.dispose);
  return bus;
});

/// Converts [DioException] into [ApiException] and reports the unhandled ones.
///
/// Every downstream caller therefore catches `ApiException`, never
/// `DioException` — dio must not leak past this layer.
class ErrorInterceptor extends Interceptor {
  ErrorInterceptor(this._bus);

  final ApiErrorBus _bus;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final exception = ApiException.fromDio(err);

    // Full technical detail goes to the log only, never to the UI.
    AppLogger.network(
      '${err.requestOptions.method} ${err.requestOptions.path} '
      '-> ${exception.statusCode ?? exception.kind.name}',
      error: exception.raw,
    );

    final shouldReport =
        !err.requestOptions.skipGlobalError &&
        exception.kind != ApiErrorKind.cancelled &&
        // A 401 on a public screen is normal for guests; surfacing it produces
        // the "unauthorized" toast spam the web app had to special-case.
        !exception.isUnauthorized;

    if (shouldReport) _bus.publish(exception);

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: exception,
      ),
    );
  }
}
