//
//  snaply_exception.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

/// A failure the SDK reports: `invalid_key`, `origin_mismatch`, `quota_exceeded`, …
class SnaplyException implements Exception {
  const SnaplyException({
    required this.code,
    required this.message,
    this.status = 0,
  });

  final String code;
  final String message;
  final int status;

  @override
  String toString() => 'SnaplyException($code): $message';
}
