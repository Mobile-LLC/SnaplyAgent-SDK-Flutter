//
//  snaply_input_test.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaply_agent/snaply_agent.dart';
import 'package:snaply_agent/src/snaply_frame.dart';
import 'package:snaply_agent/src/snaply_input.dart';
import 'package:snaply_agent/src/snaply_rule.dart';

void main() {
  setUp(() => SnaplyFrame.rules = const []);

  Future<bool> send(WidgetTester tester, Map<String, Object?> input) async {
    final sent = SnaplyInput.apply(input);
    await tester.pump(const Duration(milliseconds: 60));
    final taken = await sent;
    await tester.pump();
    return taken;
  }

  Widget screen({
    required VoidCallback onOpen,
    required VoidCallback onHidden,
  }) => MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: 50,
            top: 50,
            width: 200,
            height: 60,
            child: ElevatedButton(onPressed: onOpen, child: const Text('Open')),
          ),
          Positioned(
            left: 50,
            top: 200,
            width: 200,
            height: 60,
            child: SnaplyRedact(
              child: ElevatedButton(
                onPressed: onHidden,
                child: const Text('Hidden'),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  testWidgets(
    'a tap presses what is under it, and nothing inside a hidden area',
    (tester) async {
      var opened = 0;
      var hidden = 0;
      await tester.pumpWidget(
        screen(onOpen: () => opened++, onHidden: () => hidden++),
      );

      expect(
        await send(tester, {'action': 'tap', 'x': 150.0, 'y': 80.0}),
        isTrue,
      );
      expect(
        await send(tester, {'action': 'tap', 'x': 150.0, 'y': 230.0}),
        isTrue,
      );

      expect(opened, 1);
      expect(hidden, 0);
    },
  );

  testWidgets('a scroll moves the list under it by the distance asked', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: [
              for (var i = 0; i < 60; i++)
                SizedBox(height: 50, child: Text('row $i')),
            ],
          ),
        ),
      ),
    );

    await send(tester, {
      'action': 'scroll',
      'x': 200.0,
      'y': 300.0,
      'dx': 0.0,
      'dy': 120.0,
    });

    expect(controller.offset, 120);
  });

  testWidgets('a scroll over a hidden area still moves the screen', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: [
              const SnaplyRedact(
                child: SizedBox(height: 400, child: Text('4242 4242')),
              ),
              for (var i = 0; i < 60; i++)
                SizedBox(height: 50, child: Text('row $i')),
            ],
          ),
        ),
      ),
    );

    await send(tester, {
      'action': 'scroll',
      'x': 200.0,
      'y': 200.0,
      'dx': 0.0,
      'dy': 90.0,
    });

    expect(controller.offset, 90);
  });

  testWidgets(
    'typed text goes into the focused field at the cursor; backspace takes one character',
    (tester) async {
      final controller = TextEditingController(text: 'Leave at the door');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller, autofocus: true),
          ),
        ),
      );
      await tester.pump();
      controller.selection = const TextSelection.collapsed(offset: 17);

      expect(
        await send(tester, {'action': 'type', 'text': ' please👍'}),
        isTrue,
      );
      expect(controller.text, 'Leave at the door please👍');

      expect(await send(tester, {'action': 'key', 'key': 'backspace'}), isTrue);
      expect(controller.text, 'Leave at the door please');
      expect(controller.selection.baseOffset, controller.text.length);
    },
  );

  testWidgets(
    'nothing is typed into a password field, a marked field or one a rule hides',
    (tester) async {
      final password = TextEditingController();
      final marked = TextEditingController();
      final ruled = TextEditingController();
      final focus = [FocusNode(), FocusNode(), FocusNode()];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  controller: password,
                  focusNode: focus[0],
                  obscureText: true,
                ),
                SnaplyRedact(
                  child: TextField(controller: marked, focusNode: focus[1]),
                ),
                TextField(
                  controller: ruled,
                  focusNode: focus[2],
                  decoration: const InputDecoration(
                    hintText: 'Passport number',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      SnaplyFrame.rules = const [
        SnaplyRule(byIdentifier: false, value: 'passport'),
      ];

      for (final node in focus) {
        node.requestFocus();
        await tester.pump();
        expect(
          await send(tester, {'action': 'type', 'text': 'x'}),
          isTrue,
          reason: 'the field is ours to refuse',
        );
      }

      expect(password.text, isEmpty);
      expect(marked.text, isEmpty);
      expect(ruled.text, isEmpty);
    },
  );

  testWidgets(
    'enter submits a single-line field; with no field focused the input is not taken',
    (tester) async {
      String? submitted;
      final focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              focusNode: focus,
              onSubmitted: (value) => submitted = value,
              controller: TextEditingController(text: 'AB-12'),
            ),
          ),
        ),
      );

      expect(await send(tester, {'action': 'type', 'text': 'x'}), isFalse);

      focus.requestFocus();
      await tester.pump();
      expect(await send(tester, {'action': 'key', 'key': 'enter'}), isTrue);
      expect(submitted, 'AB-12');
    },
  );
}
