import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/social/domain/post_composer_draft.dart';

abstract final class PostComposerFormControl {
  static const content = 'content';
  static const images = 'images';
  static const location = 'location';
}

Map<String, Object>? validatePostContent(AbstractControl<dynamic> control) {
  final value = control.value;
  return value is String && value.trim().isNotEmpty
      ? null
      : {ValidationMessage.required: true};
}

FormGroup createPostComposerReactiveForm() => FormGroup({
  PostComposerFormControl.content: FormControl<String>(
    value: '',
    validators: [Validators.delegate(validatePostContent)],
  ),
  PostComposerFormControl.images: FormControl<List<PostImageDraft>>(
    value: const [],
  ),
  PostComposerFormControl.location: FormControl<PostLocationDraft>(),
});

PostComposerDraft postComposerDraftFromForm(FormGroup form) {
  final content =
      form.control(PostComposerFormControl.content).value as String? ?? '';
  final images =
      form.control(PostComposerFormControl.images).value
          as List<PostImageDraft>? ??
      const [];
  final location =
      form.control(PostComposerFormControl.location).value
          as PostLocationDraft?;
  return PostComposerDraft(
    content: content.trim(),
    images: List.unmodifiable(images),
    location: location,
  );
}
