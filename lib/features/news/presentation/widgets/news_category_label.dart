import 'package:vmito_app/features/news/domain/article.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

String newsCategoryLabel(AppLocalizations l10n, ArticleCategory category) =>
    switch (category) {
      ArticleCategory.news => l10n.newsCategoryNews,
      ArticleCategory.tutorial => l10n.newsCategoryTutorial,
      ArticleCategory.tournament => l10n.newsCategoryTournament,
      ArticleCategory.equipment => l10n.newsCategoryEquipment,
      ArticleCategory.community => l10n.newsCategoryCommunity,
    };
