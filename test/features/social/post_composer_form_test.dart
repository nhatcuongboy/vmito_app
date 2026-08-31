import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/social/domain/form/post_composer_reactive_form.dart';
import 'package:vmito_app/features/social/domain/post_composer_draft.dart';

void main() {
  test('post composer requires trimmed content', () {
    final form = createPostComposerReactiveForm();
    addTearDown(form.dispose);

    form.control(PostComposerFormControl.content).value = '   ';

    expect(form.invalid, isTrue);
    expect(
      form.control(PostComposerFormControl.content).hasError('required'),
      isTrue,
    );
  });

  test('post composer serializes location and image order for the API', () {
    final form = createPostComposerReactiveForm();
    addTearDown(form.dispose);
    form.control(PostComposerFormControl.content).value = '  Chào mọi người  ';
    form.control(PostComposerFormControl.images).value = const [
      PostImageDraft(url: 'https://image.test/second.jpg', publicId: 'second'),
      PostImageDraft(url: 'https://image.test/first.jpg', publicId: 'first'),
    ];
    form
        .control(PostComposerFormControl.location)
        .value = const PostLocationDraft(
      name: 'Sân A',
      address: 'Quận 7, TP.HCM',
      latitude: 10.73,
      longitude: 106.72,
    );

    expect(postComposerDraftFromForm(form).toJson(), {
      'content': 'Chào mọi người',
      'location': {
        'name': 'Sân A',
        'address': 'Quận 7, TP.HCM',
        'lat': 10.73,
        'lng': 106.72,
      },
      'images': [
        {
          'url': 'https://image.test/second.jpg',
          'publicId': 'second',
          'order': 0,
        },
        {
          'url': 'https://image.test/first.jpg',
          'publicId': 'first',
          'order': 1,
        },
      ],
    });
  });
}
