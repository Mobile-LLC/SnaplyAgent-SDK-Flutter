//
//  snaply_environment.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

/// Which Snaply deployment the SDK talks to.
class SnaplyEnvironment {
  const SnaplyEnvironment._(this.url);

  /// A self-hosted host, or a backend on your own machine. Plain `http` is accepted for loopback only.
  const SnaplyEnvironment.custom(String url) : this._(url);

  static const SnaplyEnvironment live = SnaplyEnvironment._(null);

  /// Null for [live].
  final String? url;
}
