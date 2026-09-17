import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:uuid/uuid.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/chat/data/chat_service.dart';
import 'package:vmito_app/features/chat/domain/chat_contact.dart';
import 'package:vmito_app/features/chat/domain/chat_mode.dart';
import 'package:vmito_app/features/chat/domain/form/chat_request_form.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

/// `/chat/new`. Either a free-form contact search, or — when reached from a
/// public profile's "Nhắn tin" CTA — a single preselected target.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({
    this.targetUserId,
    this.targetName,
    this.targetImage,
    this.targetChatMode,
    super.key,
  });

  final String? targetUserId;
  final String? targetName;
  final String? targetImage;
  final ChatMode? targetChatMode;

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  late final FormGroup _searchForm;
  late final StreamSubscription<Object?> _querySubscription;
  Timer? _debounce;
  var _results = const <ChatContact>[];
  pagination.Page<ChatContact>? _page;
  var _isSearching = false;
  var _isLoadingMore = false;
  Object? _searchError;

  bool get _hasPreselectedTarget => widget.targetUserId != null;

  FormControl<String> get _queryControl =>
      _searchForm.control('query') as FormControl<String>;

  @override
  void initState() {
    super.initState();
    _searchForm = FormGroup({'query': FormControl<String>()});
    _querySubscription = _queryControl.valueChanges.listen(
      (_) => _scheduleSearch(),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_querySubscription.cancel());
    _searchForm.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    final query = _queryControl.value?.trim() ?? '';
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _page = null;
        _isSearching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final page = await ref
            .read(chatServiceProvider)
            .contacts(search: query);
        if (!mounted) return;
        setState(() {
          _results = page.items;
          _page = page;
          _isSearching = false;
          _searchError = null;
        });
      } on Object catch (error) {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _searchError = error;
        });
      }
    });
  }

  Future<void> _loadMore() async {
    final page = _page;
    final query = _queryControl.value?.trim() ?? '';
    if (page == null || !page.hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final next = await ref
          .read(chatServiceProvider)
          .contacts(search: query, page: page.nextPage!);
      if (!mounted) return;
      setState(() {
        _results = [..._results, ...next.items];
        _page = next;
        _isLoadingMore = false;
      });
    } on Object {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatNewTitle)),
      body: SafeArea(
        child: _hasPreselectedTarget
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _TargetActionSection(
                  key: ValueKey(widget.targetUserId),
                  userId: widget.targetUserId!,
                  name: widget.targetName ?? '',
                  image: widget.targetImage,
                  chatMode: widget.targetChatMode,
                ),
              )
            : _buildSearch(context, l10n),
      ),
    );
  }

  Widget _buildSearch(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppReactiveForm<void>(
            formGroup: _searchForm,
            child: ReactiveTextField<String>(
              formControlName: 'query',
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.chatSearchHint,
                prefixIcon: const Icon(AppIcons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        Expanded(child: _buildResults(context, l10n)),
      ],
    );
  }

  Widget _buildResults(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final query = _queryControl.value?.trim() ?? '';

    if (query.length < 2) {
      return Center(
        child: Text(
          l10n.chatSearchMinChars,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.mutedForeground,
          ),
        ),
      );
    }
    if (_isSearching && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchError != null && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            _searchError is ApiException
                ? (_searchError! as ApiException).message
                : l10n.chatConsentError,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          l10n.chatSearchEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.mutedForeground,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: _results.length + ((_page?.hasMore ?? false) ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          unawaited(_loadMore());
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final contact = _results[index];
        if (contact.chatMode == ChatMode.unavailable) {
          return const SizedBox.shrink();
        }
        return _ContactTile(contact: contact);
      },
    );
  }
}

class _ContactTile extends StatefulWidget {
  const _ContactTile({required this.contact});

  final ChatContact contact;

  @override
  State<_ContactTile> createState() => _ContactTileState();
}

class _ContactTileState extends State<_ContactTile> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundImage: (contact.image?.isNotEmpty ?? false)
                ? CachedNetworkImageProvider(contact.image!)
                : null,
            child: (contact.image?.isNotEmpty ?? false)
                ? null
                : Text(
                    contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : '?',
                  ),
          ),
          title: Text(contact.name),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: _TargetActionSection(
              userId: contact.id,
              name: contact.name,
              image: contact.image,
              chatMode: contact.chatMode,
            ),
          ),
      ],
    );
  }
}

/// The action for one target: instant "opening…" for [ChatMode.direct], or a
/// one-message composer for [ChatMode.request].
///
/// [chatMode] is optional — the public-profile CTA already knows it (avoids
/// a fetch), but entry points that only have a bare user id (session detail,
/// host detail sheet) pass null and this widget resolves it itself via
/// [publicUserProvider], which carries `chatMode` on `PublicProfile`.
class _TargetActionSection extends ConsumerStatefulWidget {
  const _TargetActionSection({
    required this.userId,
    required this.name,
    this.chatMode,
    this.image,
    super.key,
  });

  final String userId;
  final String name;
  final String? image;
  final ChatMode? chatMode;

  @override
  ConsumerState<_TargetActionSection> createState() =>
      _TargetActionSectionState();
}

class _TargetActionSectionState extends ConsumerState<_TargetActionSection> {
  late final FormGroup _form;
  var _isSubmitting = false;
  Object? _error;
  ChatMode? _resolvedChatMode;
  Object? _resolveError;

  @override
  void initState() {
    super.initState();
    _form = createChatRequestForm();
    _resolvedChatMode = widget.chatMode;
    if (_resolvedChatMode == null) {
      unawaited(_resolveChatMode());
    } else if (_resolvedChatMode == ChatMode.direct) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_openDirect()),
      );
    }
  }

  Future<void> _resolveChatMode() async {
    try {
      final profile = await ref.read(publicUserProvider(widget.userId).future);
      if (!mounted) return;
      setState(() => _resolvedChatMode = profile.chatMode);
      if (profile.chatMode == ChatMode.direct) {
        await _openDirect();
      }
    } on Object catch (error) {
      if (mounted) setState(() => _resolveError = error);
    }
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _openDirect() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final conversation = await ref
          .read(chatServiceProvider)
          .direct(widget.userId);
      if (!mounted) return;
      context.pushReplacement(AppRoutes.chatChannel(conversation.channel.id));
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendRequest() async {
    _form.markAllAsTouched();
    if (_form.invalid || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final conversation = await ref
          .read(chatServiceProvider)
          .sendRequest(
            targetUserId: widget.userId,
            text: (_form.value['message']! as String).trim(),
            idempotencyKey: const Uuid().v4(),
          );
      if (!mounted) return;
      context.pushReplacement(
        AppRoutes.chatChannel(
          conversation.channel.id,
          requestId: conversation.id,
        ),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final chatMode = _resolvedChatMode;

    if (chatMode == null) {
      if (_resolveError == null) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _resolveError is ApiException
                ? (_resolveError! as ApiException).message
                : l10n.chatConsentError,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: () => unawaited(_resolveChatMode()),
            child: Text(l10n.commonRetry),
          ),
        ],
      );
    }

    if (chatMode == ChatMode.unavailable) {
      return Text(
        l10n.chatTargetUnavailable,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.extension<AppPalette>()!.mutedForeground,
        ),
      );
    }

    if (chatMode == ChatMode.direct) {
      if (_error == null) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _error is ApiException
                ? (_error! as ApiException).message
                : l10n.chatConsentError,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _isSubmitting ? null : () => unawaited(_openDirect()),
            child: Text(l10n.commonRetry),
          ),
        ],
      );
    }

    return AppReactiveForm<void>(
      formGroup: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.chatSendRequestHint(widget.name),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.extension<AppPalette>()!.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ReactiveTextField<String>(
            formControlName: 'message',
            maxLines: 3,
            maxLength: chatMessageMaxLength,
            decoration: InputDecoration(
              hintText: l10n.chatSendRequestPlaceholder,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                _error is ApiException
                    ? (_error! as ApiException).message
                    : l10n.chatConsentError,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: _isSubmitting ? null : () => unawaited(_sendRequest()),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.chatSendRequestSubmit),
          ),
        ],
      ),
    );
  }
}
