//
//  hidden_areas_test.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaply_agent/snaply_agent.dart';
import 'package:snaply_agent/src/hidden_areas.dart';
import 'package:snaply_agent/src/snaply_rule.dart';

Widget app(Widget body) => MaterialApp(home: Scaffold(body: body));

Widget placed(Widget child, {double top = 100}) => Stack(
  children: [
    Positioned(left: 50, top: top, width: 300, height: 60, child: child),
  ],
);

void main() {
  const identifierRule = SnaplyRule(
    byIdentifier: true,
    value: 'ibanField',
    label: 'Account',
  );
  const textRule = SnaplyRule(byIdentifier: false, value: 'passport');

  testWidgets(
    'a SnaplyRedact subtree is hidden where it is drawn, with its label',
    (tester) async {
      await tester.pumpWidget(
        app(
          placed(const SnaplyRedact(label: 'CARD', child: Text('4242 4242'))),
        ),
      );

      final areas = HiddenAreas.collect(const []);

      expect(areas, hasLength(1));
      expect(areas.single.rect, const Rect.fromLTWH(50, 100, 300, 60));
      expect(areas.single.label, 'CARD');
    },
  );

  testWidgets(
    'obscured fields are hidden on their own; an ordinary field is not',
    (tester) async {
      await tester.pumpWidget(
        app(
          const Column(
            children: [
              TextField(obscureText: true),
              CupertinoTextField(obscureText: true),
              TextField(),
            ],
          ),
        ),
      );

      expect(HiddenAreas.collect(const []), hasLength(2));
    },
  );

  testWidgets('a Semantics identifier carrying the mark hides its child', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        placed(
          Semantics(
            identifier: 'snaply-redact-address',
            child: const Text('12 Rue des Lilas'),
          ),
        ),
      ),
    );

    expect(HiddenAreas.collect(const []).single.rect.top, 100);
  });

  testWidgets(
    'an identifier rule names a Semantics identifier or a string key, exactly',
    (tester) async {
      await tester.pumpWidget(
        app(
          Column(
            children: [
              Semantics(identifier: 'ibanField', child: const TextField()),
              const TextField(key: ValueKey('ibanField')),
              Semantics(identifier: 'ibanField2', child: const TextField()),
              const TextField(key: ValueKey('IBANFIELD')),
            ],
          ),
        ),
      );

      final areas = HiddenAreas.collect(const [identifierRule]);

      expect(areas, hasLength(2));
      expect(areas.map((area) => area.label), everyElement('Account'));
      expect(HiddenAreas.collect(const []), isEmpty);
    },
  );

  testWidgets(
    'a text rule finds a label, a hint or a placeholder, in any case',
    (tester) async {
      await tester.pumpWidget(
        app(
          Column(
            children: [
              const TextField(
                decoration: InputDecoration(hintText: 'Passport number'),
              ),
              const TextField(
                decoration: InputDecoration(labelText: 'PASSPORT'),
              ),
              const CupertinoTextField(placeholder: 'passport'),
              Semantics(
                label: 'Passport scan',
                child: const SizedBox(width: 40, height: 40),
              ),
              const TextField(
                decoration: InputDecoration(hintText: 'Delivery note'),
              ),
            ],
          ),
        ),
      );

      expect(HiddenAreas.collect(const [textRule]), hasLength(4));
      expect(HiddenAreas.collect(const [identifierRule]), isEmpty);
    },
  );

  testWidgets('what is certainly not painted is not boxed', (tester) async {
    await tester.pumpWidget(
      app(
        Column(
          children: [
            const Offstage(child: SnaplyRedact(child: Text('offstage'))),
            const Opacity(
              opacity: 0,
              child: SnaplyRedact(child: Text('transparent')),
            ),
            const SizedBox(
              height: 60,
              child: IndexedStack(
                index: 1,
                children: [
                  SnaplyRedact(child: Text('another tab')),
                  Text('this tab'),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    expect(HiddenAreas.collect(const []), isEmpty);
  });

  testWidgets(
    'a field on a route under an opaque route is not boxed; under a dialog it still is',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: SnaplyRedact(child: Text('below'))),
        ),
      );
      expect(HiddenAreas.collect(const []), hasLength(1));

      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(title: Text('Sure?')),
      );
      await tester.pumpAndSettle();
      expect(
        HiddenAreas.collect(const []),
        hasLength(1),
        reason: 'the page shows through a dialog',
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('on top')),
        ),
      );
      await tester.pumpAndSettle();
      expect(HiddenAreas.collect(const []), isEmpty);
    },
  );

  testWidgets(
    'a hidden row is clipped to the list it scrolls in, and gone once scrolled away',
    (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        app(
          Column(
            children: [
              const SizedBox(height: 100, child: Text('header')),
              SizedBox(
                height: 200,
                child: ListView(
                  controller: controller,
                  children: [
                    const SnaplyRedact(
                      child: SizedBox(height: 80, child: Text('secret')),
                    ),
                    for (var i = 0; i < 20; i++)
                      SizedBox(height: 80, child: Text('row $i')),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      controller.jumpTo(40);
      await tester.pump();
      final clipped = HiddenAreas.collect(const []).single.rect;
      expect(
        clipped.top,
        100,
        reason: 'the box must not reach over the header',
      );
      expect(clipped.bottom, 140);

      controller.jumpTo(600);
      await tester.pump();
      expect(HiddenAreas.collect(const []), isEmpty);
    },
  );

  testWidgets('covers answers for a point in logical pixels', (tester) async {
    await tester.pumpWidget(
      app(placed(const SnaplyRedact(child: Text('secret')))),
    );

    expect(HiddenAreas.covers(const Offset(100, 120), const []), isTrue);
    expect(HiddenAreas.covers(const Offset(100, 300), const []), isFalse);
  });
}
