//
//  snaply_frame_test.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaply_agent/snaply_agent.dart';
import 'package:snaply_agent/src/snaply_frame.dart';

void main() {
  testWidgets(
    'a frame is the screen at the asked width, with its hidden areas in the same pixels',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ColoredBox(
            color: const Color(0xFF0000FF),
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  top: 0,
                  width: 200,
                  height: 150,
                  child: ColoredBox(color: Color(0xFFFF0000)),
                ),
                Positioned(
                  left: 400,
                  top: 300,
                  width: 200,
                  height: 150,
                  child: Semantics(
                    identifier: 'ibanField',
                    child: const SnaplyRedact(
                      label: 'IBAN',
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final frame = await tester.runAsync(
        () => SnaplyFrame.capture({
          'width': 400,
          'height': 300,
          'rules': [
            {'kind': 'id', 'value': 'ibanField', 'label': 'Account'},
          ],
        }),
      );

      expect(frame, isNotNull);
      expect(frame!['width'], 400);
      expect(frame['height'], 300);
      final pixels = frame['pixels']! as Uint8List;
      expect(pixels.length, 400 * 300 * 4);
      List<int> at(int x, int y) =>
          pixels.sublist((y * 400 + x) * 4, (y * 400 + x) * 4 + 3);
      expect(
        at(50, 40),
        [255, 0, 0],
        reason: 'the red box is the top-left quarter of the top-left quarter',
      );
      expect(at(150, 40), [0, 0, 255]);
      expect(at(50, 110), [0, 0, 255]);

      // The rule's own area wins over the SnaplyRedact inside it: one box, with the rule's label.
      expect(frame['hidden'], Float64List.fromList([200, 150, 300, 225]));
      expect(frame['labels'], ['Account']);
      expect(SnaplyFrame.rules.single.value, 'ibanField');
    },
  );

  testWidgets('a request without a width is refused', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(
      await tester.runAsync(() => SnaplyFrame.capture({'height': 300})),
      isNull,
    );
    expect(await tester.runAsync(() => SnaplyFrame.capture(null)), isNull);
  });
}
