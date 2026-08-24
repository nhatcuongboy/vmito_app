import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

enum LegalDocument { terms, privacy }

class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      initialIndex: document.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.settingsTermsPrivacy),
          bottom: TabBar(
            onTap: (index) {
              final path = index == LegalDocument.terms.index
                  ? AppRoutes.terms
                  : AppRoutes.privacy;
              if (GoRouterState.of(context).uri.path != path) {
                context.replace(path);
              }
            },
            tabs: [
              Tab(text: l10n.legalTermsTab),
              Tab(text: l10n.legalPrivacyTab),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _LegalDocumentView(content: _terms(l10n)),
            _LegalDocumentView(content: _privacy(l10n)),
          ],
        ),
      ),
    );
  }
}

class _LegalContent {
  const _LegalContent({
    required this.title,
    required this.lastUpdated,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String lastUpdated;
  final String intro;
  final List<({String heading, String body})> sections;
}

class _LegalDocumentView extends StatelessWidget {
  const _LegalDocumentView({required this.content});

  final _LegalContent content;

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: ListView(
      key: PageStorageKey(content.title),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.lg,
        AppSpacing.screenPadding,
        AppSpacing.xxl,
      ),
      children: [
        Text(content.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          content.lastUpdated,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(content.intro, style: const TextStyle(height: 1.5)),
        for (final section in content.sections) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(section.heading, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(section.body, style: const TextStyle(height: 1.5)),
        ],
      ],
    ),
  );
}

_LegalContent _terms(AppLocalizations l10n) => _LegalContent(
  title: l10n.legalTermsTitle,
  lastUpdated: l10n.legalTermsLastUpdated,
  intro: l10n.legalTermsIntro,
  sections: [
    (
      heading: l10n.legalTermsSection1Heading,
      body: l10n.legalTermsSection1Body,
    ),
    (
      heading: l10n.legalTermsSection2Heading,
      body: l10n.legalTermsSection2Body,
    ),
    (
      heading: l10n.legalTermsSection3Heading,
      body: l10n.legalTermsSection3Body,
    ),
    (
      heading: l10n.legalTermsSection4Heading,
      body: l10n.legalTermsSection4Body,
    ),
    (
      heading: l10n.legalTermsSection5Heading,
      body: l10n.legalTermsSection5Body,
    ),
    (
      heading: l10n.legalTermsSection6Heading,
      body: l10n.legalTermsSection6Body,
    ),
    (
      heading: l10n.legalTermsSection7Heading,
      body: l10n.legalTermsSection7Body,
    ),
    (
      heading: l10n.legalTermsSection8Heading,
      body: l10n.legalTermsSection8Body,
    ),
    (
      heading: l10n.legalTermsSection9Heading,
      body: l10n.legalTermsSection9Body,
    ),
    (
      heading: l10n.legalTermsSection10Heading,
      body: l10n.legalTermsSection10Body,
    ),
  ],
);

_LegalContent _privacy(AppLocalizations l10n) => _LegalContent(
  title: l10n.legalPrivacyTitle,
  lastUpdated: l10n.legalPrivacyLastUpdated,
  intro: l10n.legalPrivacyIntro,
  sections: [
    (
      heading: l10n.legalPrivacySection1Heading,
      body: l10n.legalPrivacySection1Body,
    ),
    (
      heading: l10n.legalPrivacySection2Heading,
      body: l10n.legalPrivacySection2Body,
    ),
    (
      heading: l10n.legalPrivacySection3Heading,
      body: l10n.legalPrivacySection3Body,
    ),
    (
      heading: l10n.legalPrivacySection4Heading,
      body: l10n.legalPrivacySection4Body,
    ),
    (
      heading: l10n.legalPrivacySection5Heading,
      body: l10n.legalPrivacySection5Body,
    ),
    (
      heading: l10n.legalPrivacySection6Heading,
      body: l10n.legalPrivacySection6Body,
    ),
    (
      heading: l10n.legalPrivacySection7Heading,
      body: l10n.legalPrivacySection7Body,
    ),
    (
      heading: l10n.legalPrivacySection8Heading,
      body: l10n.legalPrivacySection8Body,
    ),
  ],
);
