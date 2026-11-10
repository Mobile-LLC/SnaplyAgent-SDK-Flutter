//
//  snaply_redact.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Hides [child] in every screenshot and live frame, and from remote control. The box is painted on
/// the device before the image is encoded.
class SnaplyRedact extends SingleChildRenderObjectWidget {
  const SnaplyRedact({super.key, this.label, required Widget super.child});

  /// The caption on the box; null shows the default.
  final String? label;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderProxyBox();
}
