//
//  snaply.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'snaply_callbacks.dart';
import 'snaply_capture.dart';
import 'snaply_environment.dart';
import 'snaply_exception.dart';
import 'snaply_frame.dart';
import 'snaply_input.dart';
import 'snaply_user.dart';

/// Snaply Agent. Call [configure] once at app start; nothing else is needed for captures to work.
abstract final class Snaply {
  static const MethodChannel _channel = MethodChannel('snaply_agent');
  static SnaplyCallbacks _callbacks = const SnaplyCallbacks();
  static bool _listening = false;

  /// Registers this device and connects. [key]: Console → Products → your product → API key.
  static Future<void> configure({
    required String key,
    SnaplyEnvironment environment = SnaplyEnvironment.live,
    SnaplyUser? user,
    bool collectVendorId = true,
    String language = 'en',
  }) {
    _listen();
    return _invoke('configure', {
      'key': key,
      'environment': environment.url,
      'userId': user?.id,
      'userName': user?.name,
      'collectVendorId': collectVendorId,
      'language': language,
    });
  }

  /// Observe SDK events. Attach before [configure]: a request can arrive as soon as the device registers.
  static void on(SnaplyCallbacks callbacks) {
    _callbacks = callbacks;
    _listen();
  }

  /// Attaches the signed-in person. [phone] is E.164; [identitySignature] is computed on your server.
  static Future<void> identify({
    required String id,
    String? name,
    String? phone,
    String? identitySignature,
  }) => _invoke('identify', {
    'id': id,
    'name': name,
    'phone': phone,
    'identitySignature': identitySignature,
  });

  /// Detaches the person, on sign-out. The device keeps its support code.
  static Future<void> reset() => _invoke('reset');

  /// The code an anonymous caller reads to the agent.
  static Future<String?> supportCode() async =>
      await _invoke('supportCode') as String?;

  /// Shows the support code in the SDK's own sheet.
  static Future<void> showSupportCode() => _invoke('showSupportCode');

  /// Disconnects and removes any visible prompt.
  static Future<void> stop() => _invoke('stop');

  static Future<Object?> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (error) {
      final details = error.details;
      throw SnaplyException(
        code: error.code,
        message: error.message ?? error.code,
        status: details is int ? details : 0,
      );
    } on MissingPluginException {
      throw const SnaplyException(
        code: 'unsupported_platform',
        message: 'Snaply Agent runs on iOS and Android.',
        status: 0,
      );
    }
  }

  static void _listen() {
    if (_listening) return;
    _listening = true;
    WidgetsFlutterBinding.ensureInitialized();
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static Future<Object?> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'snapshot':
        return SnaplyFrame.capture(call.arguments);
      case 'control':
        return SnaplyInput.apply(call.arguments);
      case 'event':
        _dispatch(call.arguments);
    }
    return null;
  }

  static void _dispatch(Object? event) {
    if (event is! Map) return;
    switch (event['name']) {
      case 'requestShown':
        _callbacks.onRequestShown?.call();
      case 'allowed':
        _callbacks.onAllowed?.call(
          SnaplyCapture(
            captureId: event['captureId'] as String? ?? '',
            imageUrl: event['imageUrl'] as String? ?? '',
          ),
        );
      case 'denied':
        _callbacks.onDenied?.call();
      case 'expired':
        _callbacks.onExpired?.call();
      case 'error':
        _callbacks.onError?.call(
          SnaplyException(
            code: event['code'] as String? ?? 'error',
            message: event['message'] as String? ?? '',
            status: event['status'] as int? ?? 0,
          ),
        );
      case 'remoteControl':
        _callbacks.onRemoteControl?.call(event['active'] == true);
      case 'liveEnded':
        _callbacks.onLiveEnded?.call(event['sessionId'] as String? ?? '');
    }
  }
}
