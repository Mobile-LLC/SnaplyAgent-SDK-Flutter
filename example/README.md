# Example

A complete app lives in its own repository:
<https://github.com/Mobile-LLC/SnaplyAgent-Example-Flutter>.

The whole integration:

```dart
import 'package:flutter/material.dart';
import 'package:snaply_agent/snaply_agent.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Snaply.on(SnaplyCallbacks(onError: (error) => debugPrint('Snaply: $error')));
  Snaply.configure(key: 'snap_live_REPLACE_WITH_YOUR_KEY');
  runApp(const MyApp());
}

// Anything a support agent should not read:
const SnaplyRedact(child: Text('4242 4242 4242 4242'));
```
