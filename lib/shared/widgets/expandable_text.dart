import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Text collapsed to a fixed number of lines with a show more/less toggle,
/// shown only when the text actually overflows that line count.
class ExpandableText extends StatefulWidget {
  const ExpandableText({required this.text, super.key});

  final String text;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  static const _collapsedLines = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = Theme.of(context).textTheme.bodyMedium;
      final hasOverflow = _hasOverflow(
        context,
        constraints.maxWidth,
        style,
      );
      final l10n = AppLocalizations.of(context);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: style,
            maxLines: hasOverflow && !_expanded ? _collapsedLines : null,
            overflow: hasOverflow && !_expanded ? TextOverflow.ellipsis : null,
          ),
          if (hasOverflow)
            TextButton.icon(
              key: const Key('host-overview-description-toggle'),
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                _expanded ? AppIcons.chevronUp : AppIcons.chevronDown,
                size: 18,
              ),
              label: Text(
                _expanded ? l10n.sessionShowLess : l10n.sessionShowMore,
              ),
            ),
        ],
      );
    },
  );

  bool _hasOverflow(BuildContext context, double maxWidth, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: _collapsedLines,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }
}
