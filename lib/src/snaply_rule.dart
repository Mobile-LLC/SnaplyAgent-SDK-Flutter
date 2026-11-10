//
//  snaply_rule.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

/// One dashboard rule (Products → Hidden fields) as the native SDK hands it over.
class SnaplyRule {
  const SnaplyRule({
    required this.byIdentifier,
    required this.value,
    this.label,
  });

  /// True: [value] is an identifier, matched exactly. False: a text, matched anywhere, any case.
  final bool byIdentifier;
  final String value;
  final String? label;

  static List<SnaplyRule> parse(Object? wire) {
    if (wire is! List) return const [];
    final rules = <SnaplyRule>[];
    for (final item in wire) {
      if (item is! Map) continue;
      final value = (item['value'] as String?)?.trim() ?? '';
      if (value.isEmpty) continue;
      final label = (item['label'] as String?)?.trim();
      rules.add(
        SnaplyRule(
          byIdentifier: item['kind'] == 'id',
          value: value,
          label: (label == null || label.isEmpty) ? null : label,
        ),
      );
    }
    return rules;
  }

  bool matchesIdentifier(String? identifier) =>
      byIdentifier && identifier != null && identifier == value;

  bool matchesText(Iterable<String?> texts) {
    if (byIdentifier) return false;
    final needle = value.toLowerCase();
    return texts.any(
      (text) => text != null && text.toLowerCase().contains(needle),
    );
  }
}
