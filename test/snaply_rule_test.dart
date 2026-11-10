//
//  snaply_rule_test.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import 'package:flutter_test/flutter_test.dart';
import 'package:snaply_agent/src/snaply_rule.dart';

void main() {
  test(
    'rules are read from the wire; one without a value is dropped and a blank label is none',
    () {
      final rules = SnaplyRule.parse([
        {'kind': 'id', 'value': ' ibanField ', 'label': ' Account '},
        {'kind': 'text', 'value': 'IBAN', 'label': '  '},
        {'kind': 'id', 'value': '   ', 'label': null},
        'not a rule',
      ]);

      expect(rules, hasLength(2));
      expect(rules[0].byIdentifier, isTrue);
      expect(rules[0].value, 'ibanField');
      expect(rules[0].label, 'Account');
      expect(rules[1].byIdentifier, isFalse);
      expect(rules[1].label, isNull);
      expect(SnaplyRule.parse(null), isEmpty);
    },
  );

  test(
    'an identifier matches exactly, a text anywhere and in any case, and never each other',
    () {
      const byId = SnaplyRule(byIdentifier: true, value: 'ibanField');
      const byText = SnaplyRule(byIdentifier: false, value: 'iban');

      expect(byId.matchesIdentifier('ibanField'), isTrue);
      expect(byId.matchesIdentifier('IBANFIELD'), isFalse);
      expect(byId.matchesIdentifier(null), isFalse);
      expect(byId.matchesText(['ibanField']), isFalse);
      expect(byText.matchesText([null, 'Your IBAN number']), isTrue);
      expect(byText.matchesText(['Delivery note']), isFalse);
      expect(byText.matchesIdentifier('iban'), isFalse);
    },
  );
}
