import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Shared visual tokens for actions that sit beside payment section headings.
abstract final class PaymentSectionHeaderStyle {
  static const double actionIconSize = 18;

  static const actionButtonStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(
      Size(0, AppSizes.minTapTarget),
    ),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    ),
  );

  static const actionIconButtonConstraints = BoxConstraints(
    minWidth: AppSizes.minTapTarget,
    minHeight: AppSizes.minTapTarget,
  );
}
