import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

final _submittedExpando = Expando<bool>('formSubmitted');
final _rewardEarlyControllerExpando = Expando<RewardEarlyPunishLateController>(
  'rewardEarlyController',
);

/// Extension on [FormGroup] providing "Reward Early, Punish Late" form validation.
///
/// In this model:
/// - **Punish Late**: Before form submission, validation errors are suppressed on
///   blur or while typing.
/// - **On Submit**: Calling [markAllAsTouched] or [markAsSubmitted] transitions
///   the form into the submitted state and reveals errors for all invalid controls.
/// - **Reward Early**: Once submitted, real-time validation is active. As soon as
///   a control satisfies validation, its error clears immediately in real-time.
/// - **On Reset**: Calling `form.reset()` returns the form to its initial unsubmitted state.
extension FormRewardEarlyPunishLateX on FormGroup {
  /// Whether a submission has been attempted for this form.
  bool get isSubmitted => _submittedExpando[this] ?? false;

  set isSubmitted(bool value) {
    _submittedExpando[this] = value;
  }

  /// Marks the form as submitted and marks all descendant controls as touched.
  ///
  /// This reveals errors on all invalid controls and activates real-time validation.
  void markAsSubmitted() {
    isSubmitted = true;
    markAllAsTouched();
  }

  /// Resets the submission state without resetting control values.
  void resetSubmitted() {
    isSubmitted = false;
  }

  /// Enables the Reward Early, Punish Late lifecycle on this [FormGroup].
  ///
  /// Returns a [RewardEarlyPunishLateController] whose [RewardEarlyPunishLateController.dispose]
  /// should be called when no longer needed (e.g. in widget dispose).
  RewardEarlyPunishLateController enableRewardEarlyPunishLate() {
    final existing = _rewardEarlyControllerExpando[this];
    if (existing != null && !existing.isDisposed) {
      return existing;
    }

    final controller = RewardEarlyPunishLateController(this);
    _rewardEarlyControllerExpando[this] = controller;
    return controller;
  }
}

/// Controller that manages touch and submission streams for a [FormGroup]
/// to enforce the Reward Early, Punish Late validation mechanism.
class RewardEarlyPunishLateController {
  RewardEarlyPunishLateController(this.formGroup) {
    _init();
  }

  final FormGroup formGroup;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  void _init() {
    // Listen to touch changes on the root FormGroup itself.
    // When formGroup.markAllAsTouched() is called, formGroup.touchChanges emits true.
    // When formGroup.reset() is called, formGroup.touchChanges emits false.
    final rootTouchSub = formGroup.touchChanges.listen((touched) {
      formGroup.isSubmitted = touched;
    });
    _subscriptions.add(rootTouchSub);

    _attachDescendantListeners(formGroup);
  }

  void _attachDescendantListeners(FormControlCollection<dynamic> collection) {
    // Listen to collection changes so dynamically added/removed controls (e.g. FormArray)
    // are automatically hooked.
    final collectionSub = collection.collectionChanges.listen((_) {
      _rebindDescendants();
    });
    _subscriptions.add(collectionSub);

    _childrenOf(collection).forEach(_bindControl);
  }

  /// [AbstractControl.forEachChild] is protected outside reactive_forms.
  /// Form groups and arrays expose their children publicly, so iterate those
  /// concrete control collections instead.
  Iterable<AbstractControl<dynamic>> _childrenOf(
    FormControlCollection<dynamic> collection,
  ) => switch (collection) {
    FormGroup() => collection.controls.values,
    FormArray() => collection.controls,
    _ => const [],
  };

  void _bindControl(AbstractControl<dynamic> control) {
    if (control is FormControlCollection<dynamic>) {
      _attachDescendantListeners(control);
    } else {
      final sub = control.touchChanges.listen((touched) {
        // If a control was touched (e.g. by focus loss/blur) before submit,
        // immediately mark it as untouched so errors remain suppressed.
        if (touched && !formGroup.isSubmitted) {
          control.markAsUntouched();
        }
      });
      _subscriptions.add(sub);
    }
  }

  void _rebindDescendants() {
    // Cancel descendant subscriptions while keeping the root touch subscription.
    while (_subscriptions.length > 1) {
      unawaited(_subscriptions.removeLast().cancel());
    }
    _attachDescendantListeners(formGroup);
  }

  /// Disposes all stream subscriptions managed by this controller.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
  }
}

/// An application-wide drop-in replacement for [ReactiveForm] that enforces
/// the "Reward Early, Punish Late" form validation UX standard.
///
/// Use this widget to wrap all user-editable forms instead of [ReactiveForm].
///
/// ### Behavior:
/// - **Before Submit**: Fields do not show validation errors on blur or while typing.
/// - **On Submit**: Calling `form.markAllAsTouched()` or [FormRewardEarlyPunishLateX.markAsSubmitted]
///   triggers error display for all invalid fields.
/// - **After Submit**: Real-time validation is active. Correcting an invalid input
///   clears the error immediately; invalid entries display errors in real time.
class AppReactiveForm<T> extends StatefulWidget {
  const AppReactiveForm({
    super.key,
    required this.formGroup,
    required this.child,
    this.canPop,
    this.onPopInvokedWithResult,
  });

  /// The form group control bound to this widget.
  final FormGroup formGroup;

  /// The widget below this widget in the tree.
  final Widget child;

  /// Determine whether a route can pop. See [PopScope] for more details.
  final ReactiveFormCanPopCallback? canPop;

  /// A callback invoked when a route is popped. See [PopScope] for more details.
  final ReactiveFormPopInvokedWithResultCallback<T>? onPopInvokedWithResult;

  @override
  State<AppReactiveForm<T>> createState() => _AppReactiveFormState<T>();
}

class _AppReactiveFormState<T> extends State<AppReactiveForm<T>> {
  RewardEarlyPunishLateController? _controller;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(AppReactiveForm<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.formGroup != widget.formGroup) {
      _controller?.dispose();
      _attachController();
    }
  }

  void _attachController() {
    _controller = widget.formGroup.enableRewardEarlyPunishLate();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveForm<T>(
      key: widget.key,
      formGroup: widget.formGroup,
      canPop: widget.canPop,
      onPopInvokedWithResult: widget.onPopInvokedWithResult,
      child: widget.child,
    );
  }
}
