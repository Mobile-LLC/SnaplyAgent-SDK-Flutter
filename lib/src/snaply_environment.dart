//
//  snaply_environment.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

/// Which Snaply deployment the SDK talks to.
class SnaplyEnvironment {
  const SnaplyEnvironment._(this.url, this.serverKeys);

  /// A self-hosted host, or a backend on your own machine. Plain `http` is accepted for loopback only.
  ///
  /// [serverKeys] are that server's master public keys (base64url). Everything the SDK and its server exchange is
  /// sealed to keys those masters vouch for; the live server's are built in, another server brings its own.
  const SnaplyEnvironment.custom(String url, {required List<String> serverKeys}) : this._(url, serverKeys);

  static const SnaplyEnvironment live = SnaplyEnvironment._(null, <String>[]);

  /// The master key of a Snaply stack running on your own machine. It is published in the source and a secret on no
  /// machine: pass it in `serverKeys` only together with the address of such a stack.
  static const String developmentMaster =
      'BBfK1HoW7C4QbWBHQYk3qP3TJRqyEh9gBw4lp2tmOR3H69m_YdmU24iYVDbWZ_0uqNqKiDwtvY7OfvVpwGBcLzA';

  /// Null for [live].
  final String? url;

  /// Empty for [live].
  final List<String> serverKeys;
}
