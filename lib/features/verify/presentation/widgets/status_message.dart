import 'package:flutter/material.dart';

/// Thông báo giữa màn hình, kèm nút hành động nếu có.
class StatusMessage extends StatelessWidget {
  const StatusMessage({required this.message, this.actionLabel, this.onAction, super.key});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (label != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(label)),
          ],
        ],
      ),
    );
  }
}
