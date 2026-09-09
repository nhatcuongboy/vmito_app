import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/home/presentation/widgets/hosted_sessions_section.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card_skeleton.dart';
import 'package:vmito_app/features/session_hosting/application/hosted_sessions_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('shows session card skeletons while hosted sessions first load', (
    tester,
  ) async {
    final completer = Completer<pagination.Page<Session>>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete(
          const pagination.Page<Session>(
            items: [],
            total: 0,
            page: 1,
            limit: 20,
            totalPages: 0,
          ),
        );
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(
            const User(
              id: 'host-1',
              email: 'host@example.com',
              role: UserRole.host,
            ),
          ),
          hostedSessionsProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HostedSessionsSection()),
        ),
      ),
    );

    expect(find.byType(SessionCardSkeleton), findsNWidgets(2));
  });
}
