//
//  snaply_callbacks.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import 'snaply_capture.dart';
import 'snaply_exception.dart';

/// What the SDK tells the app. Every callback is optional.
class SnaplyCallbacks {
  const SnaplyCallbacks({
    this.onRequestShown,
    this.onAllowed,
    this.onDenied,
    this.onExpired,
    this.onError,
    this.onRemoteControl,
    this.onLiveEnded,
  });

  final void Function()? onRequestShown;
  final void Function(SnaplyCapture capture)? onAllowed;
  final void Function()? onDenied;
  final void Function()? onExpired;
  final void Function(SnaplyException error)? onError;

  /// Remote control started (`true`) after the person allowed it, or ended.
  final void Function(bool active)? onRemoteControl;

  /// Live view stopped; the argument is the session's id.
  final void Function(String sessionId)? onLiveEnded;
}
