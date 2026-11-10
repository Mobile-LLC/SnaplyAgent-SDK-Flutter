//
//  snaply_input.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'hidden_areas.dart';
import 'snaply_frame.dart';

/// A support agent's relayed input, delivered the way a finger and a keyboard would deliver it.
/// Nothing reaches a hidden area.
abstract final class SnaplyInput {
  static const int _device = 0x5A9;
  static int _pointer = 0x5A9000;

  static Future<bool> apply(Object? arguments) async {
    if (arguments is! Map) return false;
    final position = Offset(
      (arguments['x'] as num?)?.toDouble() ?? 0,
      (arguments['y'] as num?)?.toDouble() ?? 0,
    );
    switch (arguments['action']) {
      case 'tap':
        if (!_isHidden(position)) await _tap(position);
        return true;
      case 'scroll':
        final delta = Offset(
          (arguments['dx'] as num?)?.toDouble() ?? 0,
          (arguments['dy'] as num?)?.toDouble() ?? 0,
        );
        // Not refused over a hidden area: a scroll moves the screen, it does not touch the field — the
        // native SDKs scroll from any point as well.
        GestureBinding.instance.handlePointerEvent(
          PointerScrollEvent(
            viewId: _viewId,
            device: _device,
            position: position,
            scrollDelta: delta,
          ),
        );
        return true;
      case 'type':
        final text = arguments['text'];
        return text is String &&
            _edit((value, selection) => _replace(value, selection, text));
      case 'key':
        return switch (arguments['key']) {
          'backspace' => _edit(_backspace),
          'enter' => _enter(),
          _ => false,
        };
    }
    return false;
  }

  static ui.FlutterView? get _view =>
      RendererBinding.instance.renderViews.firstOrNull?.flutterView;

  static int get _viewId => _view?.viewId ?? 0;

  static bool _isHidden(Offset logical) =>
      HiddenAreas.covers(logical, SnaplyFrame.rules);

  static Future<void> _tap(Offset position) async {
    final pointer = _pointer++;
    final binding = GestureBinding.instance;
    binding.handlePointerEvent(
      PointerAddedEvent(viewId: _viewId, device: _device, position: position),
    );
    binding.handlePointerEvent(
      PointerDownEvent(
        viewId: _viewId,
        pointer: pointer,
        device: _device,
        position: position,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    binding.handlePointerEvent(
      PointerUpEvent(
        viewId: _viewId,
        pointer: pointer,
        device: _device,
        position: position,
      ),
    );
    binding.handlePointerEvent(
      PointerRemovedEvent(viewId: _viewId, device: _device, position: position),
    );
  }

  static EditableTextState? _focusedField() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context?.findAncestorStateOfType<EditableTextState>();
  }

  // A field that is hidden in the frame is one support cannot type into either.
  static bool _isLocked(EditableTextState field) {
    if (field.widget.obscureText || field.widget.readOnly) return true;
    final box = field.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return true;
    final centre = MatrixUtils.transformPoint(
      box.getTransformTo(null),
      box.size.center(Offset.zero),
    );
    return HiddenAreas.covers(centre, SnaplyFrame.rules);
  }

  static bool _edit(
    TextEditingValue Function(String text, TextSelection selection) change,
  ) {
    final field = _focusedField();
    if (field == null) return false;
    if (_isLocked(field)) return true;
    final value = field.textEditingValue;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    field.userUpdateTextEditingValue(
      change(value.text, selection),
      SelectionChangedCause.keyboard,
    );
    return true;
  }

  static TextEditingValue _replace(
    String text,
    TextSelection selection,
    String inserted,
  ) => TextEditingValue(
    text: text.replaceRange(selection.start, selection.end, inserted),
    selection: TextSelection.collapsed(
      offset: selection.start + inserted.length,
    ),
  );

  static TextEditingValue _backspace(String text, TextSelection selection) {
    if (!selection.isCollapsed) return _replace(text, selection, '');
    if (selection.start == 0) {
      return TextEditingValue(text: text, selection: selection);
    }
    final before = text
        .substring(0, selection.start)
        .characters
        .skipLast(1)
        .toString();
    return TextEditingValue(
      text: before + text.substring(selection.start),
      selection: TextSelection.collapsed(offset: before.length),
    );
  }

  static bool _enter() {
    final field = _focusedField();
    if (field == null) return false;
    if (_isLocked(field)) return true;
    if (field.widget.maxLines == 1) {
      field.performAction(field.widget.textInputAction ?? TextInputAction.done);
      return true;
    }
    return _edit((value, selection) => _replace(value, selection, '\n'));
  }
}
