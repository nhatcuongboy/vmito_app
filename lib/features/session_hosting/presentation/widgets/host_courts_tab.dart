import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_court_card.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/session_run_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class HostCourtsTab extends ConsumerWidget {
  const HostCourtsTab({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (session.courts.isEmpty) {
      return Center(child: Text(l10n.liveNoCourts));
    }
    return RefreshIndicator(
      onRefresh: () => ref.refresh(sessionDetailProvider(session.id).future),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: session.orderedCourts.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) return SessionRunCard(session: session);
          return HostCourtCard(
            session: session,
            court: session.orderedCourts[index - 1],
          );
        },
      ),
    );
  }
}
