//
//  snaply_user.dart
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

/// The signed-in person this device belongs to.
class SnaplyUser {
  const SnaplyUser({required this.id, this.name});

  final String id;
  final String? name;
}
