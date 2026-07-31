import 'package:flutter/material.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Full-screen failure state for a load that produced nothing to show.
///
/// For a failure on top of content that is already on screen, use a SnackBar
/// instead — do not replace loaded content with this.
class AppErrorView extends StatelessWidget {
  const AppErrorView({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    final apiError = error is ApiException ? error as ApiException : null;
    final message = apiError?.message ?? ApiErrorKind.unknown.defaultMessage;
    final canRetry = onRetry != null && (apiError?.isRetryable ?? true);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              apiError?.kind == ApiErrorKind.network
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              size: 48,
              color: palette.mutedForeground,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (canRetry) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context).commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
