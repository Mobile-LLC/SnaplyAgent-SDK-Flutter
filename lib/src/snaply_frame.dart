//
//  snaply_frame.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'hidden_areas.dart';
import 'snaply_rule.dart';

/// The Flutter view's own picture of one frame, with the areas to hide read from the same frame.
abstract final class SnaplyFrame {
  /// The rules of the latest frame; remote control applies the same ones.
  static List<SnaplyRule> rules = const [];

  static Future<Map<String, Object?>?> capture(Object? arguments) async {
    if (arguments is! Map) return null;
    final width = arguments['width'];
    if (width is! int || width <= 0) return null;
    rules = SnaplyRule.parse(arguments['rules']);

    final renderView = RendererBinding.instance.renderViews.firstOrNull;
    if (renderView == null) return null;
    final physical = renderView.flutterView.physicalSize;
    if (physical.isEmpty) return null;
    // ignore: invalid_use_of_protected_member
    final layer = renderView.layer;
    if (layer is! OffsetLayer) return null;

    final ratio = width / physical.width;
    final perLogicalPixel = ratio * renderView.flutterView.devicePixelRatio;
    // Both read between frames, in one turn of the event loop: the boxes belong to these pixels.
    final areas = HiddenAreas.collect(rules);
    final image = await layer.toImage(
      Offset.zero & physical,
      pixelRatio: ratio,
    );
    try {
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (pixels == null) return null;
      final hidden = Float64List(areas.length * 4);
      for (var i = 0; i < areas.length; i++) {
        final rect = areas[i].rect;
        hidden[i * 4] = rect.left * perLogicalPixel;
        hidden[i * 4 + 1] = rect.top * perLogicalPixel;
        hidden[i * 4 + 2] = rect.right * perLogicalPixel;
        hidden[i * 4 + 3] = rect.bottom * perLogicalPixel;
      }
      return {
        'width': image.width,
        'height': image.height,
        'pixels': pixels.buffer.asUint8List(
          pixels.offsetInBytes,
          pixels.lengthInBytes,
        ),
        'hidden': hidden,
        'labels': [for (final area in areas) area.label],
      };
    } finally {
      image.dispose();
    }
  }
}
