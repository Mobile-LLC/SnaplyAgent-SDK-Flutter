//
//  snaply_capture.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

/// A screenshot the person allowed and the SDK uploaded.
class SnaplyCapture {
  const SnaplyCapture({required this.captureId, required this.imageUrl});

  final String captureId;
  final String imageUrl;
}
