import 'package:flutter/material.dart';

class SummaryChip extends StatelessWidget {
  const SummaryChip({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(label: Text('$label: $value'));
}
