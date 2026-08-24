import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/feedback/application/feedback_controller.dart';
import 'package:vmito_app/features/feedback/data/feedback_image_picker.dart';
import 'package:vmito_app/features/feedback/domain/feedback.dart';
import 'package:vmito_app/features/feedback/domain/form/feedback_form.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  late final FormGroup _contactForm;
  late final FormGroup _bugForm;
  PickedFeedbackImage? _bugImage;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _contactForm = createFeedbackForm();
    _bugForm = createFeedbackForm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(feedbackControllerProvider.notifier).load());
    });
  }

  @override
  void dispose() {
    _contactForm.dispose();
    _bugForm.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final image = await ref.read(feedbackImagePickerProvider)();
      if (image != null && mounted) {
        setState(() => _bugImage = image);
      }
    } on Object {
      if (mounted) {
        _showMessage(AppLocalizations.of(context).feedbackUploadError);
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _submit(FormGroup form, FeedbackType type) async {
    form.markAllAsTouched();
    if (form.invalid || form.pending) return;
    final success = await ref
        .read(feedbackControllerProvider.notifier)
        .submit(
          draft: feedbackDraftFromForm(form, type),
          image: type == FeedbackType.bugReport ? _bugImage : null,
        );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (!success) {
      _showMessage(l10n.feedbackSubmitError);
      return;
    }
    form.reset();
    if (type == FeedbackType.bugReport) setState(() => _bugImage = null);
    _showMessage(l10n.feedbackSubmitSuccess);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedbackControllerProvider);
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.feedbackPageTitle),
          bottom: TabBar(
            tabs: [
              Tab(
                text: l10n.feedbackContactTab,
                icon: const Icon(AppIcons.chat),
              ),
              Tab(
                text: l10n.feedbackBugReportTab,
                icon: const Icon(AppIcons.error),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FeedbackTab(
              form: _contactForm,
              type: FeedbackType.contact,
              state: state,
              onSubmit: () => _submit(_contactForm, FeedbackType.contact),
            ),
            _FeedbackTab(
              form: _bugForm,
              type: FeedbackType.bugReport,
              state: state,
              image: _bugImage,
              isPickingImage: _isPickingImage,
              onPickImage: _pickImage,
              onRemoveImage: () => setState(() => _bugImage = null),
              onSubmit: () => _submit(_bugForm, FeedbackType.bugReport),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackTab extends ConsumerWidget {
  const _FeedbackTab({
    required this.form,
    required this.type,
    required this.state,
    required this.onSubmit,
    this.image,
    this.isPickingImage = false,
    this.onPickImage,
    this.onRemoveImage,
  });

  final FormGroup form;
  final FeedbackType type;
  final FeedbackState state;
  final VoidCallback onSubmit;
  final PickedFeedbackImage? image;
  final bool isPickingImage;
  final VoidCallback? onPickImage;
  final VoidCallback? onRemoveImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final suffix = type == FeedbackType.contact ? 'contact' : 'bug';
    return RefreshIndicator(
      onRefresh: ref.read(feedbackControllerProvider.notifier).load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ReactiveForm(
            formGroup: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReactiveTextField<String>(
                  key: ValueKey('feedback-$suffix-title-field'),
                  formControlName: FeedbackFormControl.title,
                  maxLength: 200,
                  textInputAction: TextInputAction.next,
                  readOnly: state.isSubmitting,
                  decoration: InputDecoration(
                    labelText: l10n.feedbackTitleLabel,
                    hintText: l10n.feedbackTitleHint,
                  ),
                  validationMessages: {
                    ValidationMessage.required: (_) =>
                        l10n.feedbackRequiredError,
                    ValidationMessage.maxLength: (_) =>
                        l10n.feedbackTitleTooLong,
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                ReactiveTextField<String>(
                  key: ValueKey('feedback-$suffix-description-field'),
                  formControlName: FeedbackFormControl.description,
                  maxLength: 5000,
                  minLines: 5,
                  maxLines: 8,
                  readOnly: state.isSubmitting,
                  decoration: InputDecoration(
                    labelText: l10n.feedbackDescriptionLabel,
                    hintText: type == FeedbackType.contact
                        ? l10n.feedbackContactDescriptionHint
                        : l10n.feedbackBugDescriptionHint,
                    alignLabelWithHint: true,
                  ),
                  validationMessages: {
                    ValidationMessage.required: (_) =>
                        l10n.feedbackRequiredError,
                    ValidationMessage.maxLength: (_) =>
                        l10n.feedbackDescriptionTooLong,
                  },
                ),
                if (type == FeedbackType.bugReport) ...[
                  const SizedBox(height: AppSpacing.md),
                  DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.bodyMedium,
                    child: AppOptionalLabel(
                      l10n.feedbackScreenshotLabel,
                      optionalText: l10n.formOptional,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (image == null)
                    OutlinedButton.icon(
                      key: const ValueKey('feedback-pick-image'),
                      onPressed: state.isSubmitting || isPickingImage
                          ? null
                          : onPickImage,
                      icon: isPickingImage
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(AppIcons.imagePlus),
                      label: Text(l10n.feedbackUploadImage),
                    )
                  else
                    Semantics(
                      label: l10n.feedbackScreenshotLabel,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            child: Image.memory(
                              image!.bytes,
                              key: const ValueKey('feedback-image-preview'),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: AppSpacing.sm,
                            right: AppSpacing.sm,
                            child: IconButton.filled(
                              key: const ValueKey('feedback-remove-image'),
                              tooltip: l10n.feedbackRemoveImage,
                              onPressed: state.isSubmitting
                                  ? null
                                  : onRemoveImage,
                              icon: const Icon(AppIcons.close),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: ValueKey('feedback-$suffix-submit'),
                  onPressed: state.isSubmitting ? null : onSubmit,
                  icon: state.isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.send),
                  label: Text(
                    state.isSubmitting
                        ? l10n.feedbackSubmitting
                        : l10n.feedbackSubmit,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.feedbackMyFeedback,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          _FeedbackHistory(state: state),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _FeedbackHistory extends ConsumerWidget {
  const _FeedbackHistory({required this.state});

  final FeedbackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.historyError != null && state.items.isEmpty) {
      return Column(
        children: [
          Text(l10n.feedbackLoadError, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: ref.read(feedbackControllerProvider.notifier).load,
            icon: const Icon(AppIcons.refresh),
            label: Text(l10n.commonRetry),
          ),
        ],
      );
    }
    if (state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Text(
          l10n.feedbackEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < state.items.length; index++) ...[
          _FeedbackCard(item: state.items[index]),
          if (index != state.items.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.item});

  final FeedbackItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FeedbackBadge(
                  label: _typeLabel(l10n, item.type),
                  color: item.type == FeedbackType.bugReport
                      ? Theme.of(context).colorScheme.error
                      : AppColors.info,
                ),
                const SizedBox(width: AppSpacing.sm),
                _FeedbackBadge(
                  label: _statusLabel(l10n, item.status),
                  color: _statusColor(context, item.status),
                ),
                const Spacer(),
                Text(
                  Dates.dateOnly(item.createdAt, locale: locale),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(item.description),
            if (item.imageUrl?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Image.network(
                  item.imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
            if (item.adminNote?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text('${l10n.feedbackAdminNote}: ${item.adminNote}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedbackBadge extends StatelessWidget {
  const _FeedbackBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    ),
  );
}

String _typeLabel(AppLocalizations l10n, FeedbackType type) => switch (type) {
  FeedbackType.contact => l10n.feedbackTypeContact,
  FeedbackType.bugReport => l10n.feedbackTypeBugReport,
  FeedbackType.unknown => l10n.feedbackTypeUnknown,
};

String _statusLabel(AppLocalizations l10n, FeedbackStatus status) =>
    switch (status) {
      FeedbackStatus.pending => l10n.feedbackStatusPending,
      FeedbackStatus.inProgress => l10n.feedbackStatusInProgress,
      FeedbackStatus.resolved => l10n.feedbackStatusResolved,
      FeedbackStatus.closed => l10n.feedbackStatusClosed,
      FeedbackStatus.unknown => l10n.feedbackStatusUnknown,
    };

Color _statusColor(BuildContext context, FeedbackStatus status) =>
    switch (status) {
      FeedbackStatus.pending => AppColors.warning,
      FeedbackStatus.inProgress => AppColors.info,
      FeedbackStatus.resolved => AppColors.success,
      FeedbackStatus.closed => Theme.of(context).colorScheme.outline,
      FeedbackStatus.unknown => Theme.of(context).colorScheme.outline,
    };
