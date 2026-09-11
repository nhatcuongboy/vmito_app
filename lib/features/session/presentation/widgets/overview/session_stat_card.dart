import 'package:flutter/material.dart';

/// Generic stat tile: icon, value, label, optional detail line and optional
/// progress bar. The building block for `SessionStatsGrid`.
class SessionStatCard extends StatelessWidget {
  const SessionStatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.detail,
    this.progress,
    super.key,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? detail;
  final double? progress;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const Spacer(),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          if (detail != null)
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          if (progress != null) ...[
            const SizedBox(height: 5),
            LinearProgressIndicator(value: progress!.clamp(0, 1), color: color),
          ],
        ],
      ),
    ),
  );
}
