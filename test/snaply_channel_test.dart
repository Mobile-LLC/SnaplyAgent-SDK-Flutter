//
//  snaply_channel_test.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaply_agent/snaply_agent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('snaply_agent');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('configure sends the key, the host, the user and the options', () async {
    MethodCall? sent;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent = call;
      return null;
    });

    await Snaply.configure(
      key: 'snap_live_abc',
      environment: const SnaplyEnvironment.custom('http://10.0.2.2:5100'),
      user: const SnaplyUser(id: 'usr_1', name: 'Maya'),
      collectVendorId: false,
      language: 'hy',
    );

    expect(sent?.method, 'configure');
    expect(sent?.arguments, {
      'key': 'snap_live_abc',
      'environment': 'http://10.0.2.2:5100',
      'userId': 'usr_1',
      'userName': 'Maya',
      'collectVendorId': false,
      'language': 'hy',
    });
  });

  test('the live environment is sent as no host at all', () async {
    MethodCall? sent;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent = call;
      return null;
    });

    await Snaply.configure(key: 'snap_live_abc');

    expect((sent?.arguments as Map)['environment'], isNull);
    expect((sent?.arguments as Map)['userId'], isNull);
  });

  test('a native failure arrives as a SnaplyException with its code', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'origin_mismatch',
        message: 'The key does not allow this app.',
        details: 403,
      );
    });

    await expectLater(
      Snaply.configure(key: 'snap_live_abc'),
      throwsA(
        isA<SnaplyException>()
            .having((e) => e.code, 'code', 'origin_mismatch')
            .having((e) => e.status, 'status', 403),
      ),
    );
  });

  test('a platform with no native side is a clear error', () async {
    await expectLater(
      Snaply.configure(key: 'snap_live_abc'),
      throwsA(
        isA<SnaplyException>().having(
          (e) => e.code,
          'code',
          'unsupported_platform',
        ),
      ),
    );
  });

  test('native events reach the callbacks', () async {
    final seen = <String>[];
    Snaply.on(
      SnaplyCallbacks(
        onRequestShown: () => seen.add('shown'),
        onAllowed: (capture) => seen.add('allowed ${capture.captureId}'),
        onRemoteControl: (active) => seen.add('control $active'),
        onLiveEnded: (id) => seen.add('ended $id'),
        onError: (error) => seen.add('error ${error.code} ${error.status}'),
      ),
    );

    Future<void> native(Map<String, Object?> event) =>
        messenger.handlePlatformMessage(
          'snaply_agent',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('event', event),
          ),
          (_) {},
        );

    await native({'name': 'requestShown'});
    await native({'name': 'allowed', 'captureId': 'c1', 'imageUrl': '/u/1'});
    await native({'name': 'remoteControl', 'active': true});
    await native({'name': 'liveEnded', 'sessionId': 's1'});
    await native({'name': 'error', 'code': 'quota_exceeded', 'status': 429});
    await native({'name': 'denied'});

    expect(seen, [
      'shown',
      'allowed c1',
      'control true',
      'ended s1',
      'error quota_exceeded 429',
    ]);
  });
}
