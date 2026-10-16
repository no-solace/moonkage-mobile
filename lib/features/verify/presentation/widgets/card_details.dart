import 'package:flutter/material.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/domain/identity_card.dart';

/// Thông tin thẻ dạng chỉ đọc, mỗi trường một dòng.
class CardDetails extends StatelessWidget {
  const CardDetails({required this.card, super.key});

  final IdentityCard card;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      (Strings.fieldIdNumber, card.idNumber),
      (Strings.fieldFullName, card.fullName),
      (Strings.fieldDateOfBirth, Strings.date(card.dateOfBirth)),
      (
        Strings.fieldSex,
        switch (card.sex) {
          Sex.male => Strings.sexMale,
          Sex.female => Strings.sexFemale,
        },
      ),
      (Strings.fieldNationality, card.nationality),
      (Strings.fieldPlaceOfBirth, card.placeOfBirth),
      (Strings.fieldPlaceOfResidence, card.placeOfResidence),
      (Strings.fieldDateOfIssue, Strings.date(card.dateOfIssue)),
      (Strings.fieldDateOfExpiry, Strings.date(card.dateOfExpiry)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final (label, value) in rows) _Field(label: label, value: value)],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          SelectableText(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
