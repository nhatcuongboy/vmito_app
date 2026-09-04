import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_logo.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Displays the "About Vmito" modal with contact details, author information,
/// and direct links to Zalo, Messenger, Fanpage, phone, and email.
Future<void> showAboutVmitoDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _AboutVmitoDialog(),
  );
}

class _AboutVmitoDialog extends StatelessWidget {
  const _AboutVmitoDialog();

  static const String _phone = '0914810765';
  static const String _email = 'admin@vmito.com';
  static const String _fanpageUrl = 'https://www.facebook.com/vmitovn';
  static const String _zaloUrl = 'https://zalo.me/84914810765';
  static const String _messengerUrl = 'https://m.me/vmitovn';

  Future<void> _launch(
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    try {
      await launchUrl(uri, mode: mode);
    } catch (_) {
      // Ignore launch errors gracefully.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerLow;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App Logo & Header
              AppLogo(
                height: 56,
                semanticLabel: l10n.appName,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.aboutAuthor,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Contact Info Section
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xs,
                  horizontal: AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: const Icon(
                        LucideIcons.phone,
                        size: 16,
                        color: Colors.white,
                      ),
                      iconBg: const Color(0xFF22C55E),
                      text: _phone,
                      onTap: () =>
                          unawaited(_launch(Uri(scheme: 'tel', path: _phone))),
                    ),
                    Divider(
                      height: 1,
                      indent: 48,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    _InfoRow(
                      icon: const Icon(
                        LucideIcons.mail,
                        size: 16,
                        color: Colors.white,
                      ),
                      iconBg: const Color(0xFF22C55E),
                      text: _email,
                      onTap: () => unawaited(
                        _launch(Uri(scheme: 'mailto', path: _email)),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 48,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    _InfoRow(
                      icon: SvgPicture.string(
                        _facebookSvg,
                        width: 15,
                        height: 15,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      iconBg: const Color(0xFF1877F2),
                      text: 'Fanpage',
                      onTap: () => unawaited(
                        _launch(
                          Uri.parse(_fanpageUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // CTA Buttons: Zalo & Messenger
              Row(
                children: [
                  Expanded(
                    child: _ContactCtaButton(
                      label: 'Zalo',
                      bg: const Color(0xFF0068FF),
                      icon: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        padding: const EdgeInsets.all(2),
                        child: Image.asset(
                          'assets/icons/zalo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      onTap: () => unawaited(
                        _launch(
                          Uri.parse(_zaloUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: _ContactCtaButton(
                      label: 'Messenger',
                      bg: const Color(0xFF0084FF),
                      icon: SvgPicture.string(
                        _messengerSvg,
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      onTap: () => unawaited(
                        _launch(
                          Uri.parse(_messengerUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Close Action
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md - 2,
                    ),
                  ),
                  child: Text(
                    l10n.commonClose,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconBg,
    required this.text,
    required this.onTap,
  });

  final Widget icon;
  final Color iconBg;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: icon,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevron_right,
                size: 18,
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactCtaButton extends StatelessWidget {
  const _ContactCtaButton({
    required this.label,
    required this.bg,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color bg;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: bg.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: AppSpacing.xs + 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _facebookSvg = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
</svg>
''';

const _messengerSvg = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 0C5.371 0 0 5.007 0 11.184c0 3.517 1.798 6.61 4.578 8.628V24l4.248-2.331c1.073.288 2.198.451 3.174.451 6.629 0 12-5.007 12-11.184C24 5.007 18.629 0 12 0zm1.191 15.093l-3.055-3.26-5.963 3.26L10.732 8l3.13 3.259L19.752 8l-6.561 7.093z"/>
</svg>
''';
