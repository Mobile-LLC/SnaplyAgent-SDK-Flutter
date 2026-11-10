//
//  hidden_areas.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'snaply_redact.dart';
import 'snaply_rule.dart';

/// One area of the current frame that must not be seen, in the view's logical pixels.
class HiddenArea {
  const HiddenArea(this.rect, this.label);

  final Rect rect;
  final String? label;
}

/// Finds what the frame must hide: [SnaplyRedact] subtrees, obscured text fields, a `Semantics`
/// identifier carrying the mark, and whatever the dashboard's rules name.
///
/// A candidate is dropped only when it is certain it was not painted. Anything else is boxed:
/// a box too many is a complaint, a field too few is a leak.
abstract final class HiddenAreas {
  static const String mark = 'snaply-redact';

  static List<HiddenArea> collect(List<SnaplyRule> rules) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return const [];
    final areas = <HiddenArea>[];

    void add(Element element, String? label) {
      final renderObject = element.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        return;
      }
      final rect = _paintedRect(renderObject);
      if (rect != null) areas.add(HiddenArea(rect, label));
    }

    void visit(Element element) {
      final widget = element.widget;
      if (widget is SnaplyRedact) return add(element, widget.label);
      if (widget is TextField && widget.obscureText) return add(element, null);
      if (widget is CupertinoTextField && widget.obscureText) {
        return add(element, null);
      }
      if (widget is EditableText && widget.obscureText) {
        return add(element, null);
      }

      final key = widget.key;
      final identifiers = <String?>[if (key is ValueKey<String>) key.value];
      final texts = <String?>[];
      if (widget is Semantics) {
        final properties = widget.properties;
        if (properties.identifier?.contains(mark) ?? false) {
          return add(element, null);
        }
        identifiers.add(properties.identifier);
        texts
          ..add(properties.label)
          ..add(properties.hint)
          ..add(properties.tooltip);
      } else if (widget is TextField) {
        final decoration = widget.decoration;
        texts
          ..add(decoration?.labelText)
          ..add(decoration?.hintText)
          ..add(decoration?.helperText);
      } else if (widget is CupertinoTextField) {
        texts.add(widget.placeholder);
      }
      for (final rule in rules) {
        if (identifiers.any(rule.matchesIdentifier) ||
            rule.matchesText(texts)) {
          return add(element, rule.label);
        }
      }
      element.visitChildElements(visit);
    }

    root.visitChildElements(visit);
    return areas;
  }

  /// Whether [position], in the view's logical pixels, falls inside a hidden area.
  static bool covers(Offset position, List<SnaplyRule> rules) =>
      collect(rules).any((area) => area.rect.contains(position));

  /// Where [box] is on the glass, clipped as its ancestors clip it; null when it is certainly not painted.
  static Rect? _paintedRect(RenderBox box) {
    var rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    RenderObject child = box;
    var parent = box.parent;
    while (parent != null) {
      if (_dropsChild(parent, child)) return null;
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        rect = rect.intersect(
          MatrixUtils.transformRect(parent.getTransformTo(null), clip),
        );
        if (rect.isEmpty) return null;
      }
      child = parent;
      parent = parent.parent;
    }
    if (_inDetachedLayer(box)) return null;
    return rect.width > 1 && rect.height > 1 ? rect : null;
  }

  static bool _dropsChild(RenderObject parent, RenderObject child) {
    if (parent is RenderOffstage) return parent.offstage;
    if (parent is RenderOpacity) return parent.opacity == 0;
    if (parent is RenderAnimatedOpacity) return parent.opacity.value == 0;
    if (parent is RenderIndexedStack) {
      final index = parent.index;
      if (index == null) return true;
      var shown = parent.firstChild;
      for (var i = 0; i < index && shown != null; i++) {
        shown = parent.childAfter(shown);
      }
      return !identical(shown, child);
    }
    return false;
  }

  // A route under an opaque one stays in the tree and is not painted: its repaint boundary's layer
  // is no longer part of the scene.
  static bool _inDetachedLayer(RenderObject renderObject) {
    RenderObject? current = renderObject;
    while (current != null) {
      if (current.isRepaintBoundary && current is! RenderView) {
        // ignore: invalid_use_of_protected_member
        final layer = current.layer;
        if (layer == null || !layer.attached) return true;
      }
      current = current.parent;
    }
    return false;
  }
}
