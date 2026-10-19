import 'package:flutter/material.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/domain/identity_card.dart';

/// Thông tin thẻ dạng chỉ đọc, hỗ trợ che/hiện số CCCD bảo vệ quyền riêng tư.
class CardDetails extends StatefulWidget {
  const CardDetails({required this.card, super.key});

  final IdentityCard card;

  @override
  State<CardDetails> createState() => _CardDetailsState();
}

class _CardDetailsState extends State<CardDetails> {
  bool _showFullIdNumber = false;

  String _formatIdNumber(String id) {
    if (_showFullIdNumber) return id;
    if (id.length <= 6) return '••••••';
    return '${id.substring(0, 3)} ••• ••• ${id.substring(id.length - 3)}';
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final theme = Theme.of(context);

    final rows = <(String, String, Widget?)>[
      (
        Strings.fieldIdNumber,
        _formatIdNumber(card.idNumber),
        IconButton(
          icon: Icon(
            _showFullIdNumber ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          tooltip: _showFullIdNumber ? Strings.hideIdNumber : Strings.showIdNumber,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => setState(() => _showFullIdNumber = !_showFullIdNumber),
        ),
      ),
      (Strings.fieldFullName, card.fullName, null),
      (Strings.fieldDateOfBirth, Strings.date(card.dateOfBirth), null),
      (
        Strings.fieldGender,
        switch (card.gender) {
          Gender.male => Strings.genderMale,
          Gender.female => Strings.genderFemale,
        },
        null,
      ),
      (Strings.fieldNationality, card.nationality, null),
      (Strings.fieldPlaceOfBirth, card.placeOfBirth, null),
      (Strings.fieldPlaceOfResidence, card.placeOfResidence, null),
      (Strings.fieldDateOfIssue, Strings.date(card.dateOfIssue), null),
      (Strings.fieldDateOfExpiry, Strings.date(card.dateOfExpiry), null),
    ];

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
              _Field(
                label: rows[i].$1,
                value: rows[i].$2,
                trailing: rows[i].$3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
