# snaply_agent

Snaply Agent for Flutter — consent-first screen capture for support teams: a screenshot, a live view
and remote control of your app, each only after the person allows it, with sensitive fields hidden on
the device before anything is sent.

One package. No code in the `ios` or `android` folders.

## Install

```yaml
dependencies:
  snaply_agent:
    git: https://github.com/Mobile-LLC/SnaplyAgent-SDK-Flutter
```

- **iOS 15** or later: raise the deployment target of the Runner target (Flutter's template says 13).
  The package is a Swift package; it brings the Snaply Agent iOS SDK with it.
- **Android** `minSdk` 24. The package brings the Snaply Agent Android SDK from Maven Central.
- Flutter 3.44 or later.

## Use

```dart
import 'package:snaply_agent/snaply_agent.dart';

// 1. Listen first: a request can arrive as soon as the device is registered.
Snaply.on(SnaplyCallbacks(
  onAllowed: (capture) => debugPrint('Screenshot shared'),
  onError: (error) => debugPrint('Snaply: ${error.code}'),
));

// 2. Configure once. An iOS product and an Android product each have their own key
//    (Console → Products → your product → API key). A key is not a secret.
await Snaply.configure(
  key: defaultTargetPlatform == TargetPlatform.iOS ? iosKey : androidKey,
  user: const SnaplyUser(id: 'usr_20481', name: 'Maya Kowalski'), // optional
);

// When someone signs in later, and when they sign out:
await Snaply.identify(id: 'usr_20481', name: 'Maya Kowalski');
await Snaply.reset();

// An anonymous caller reads this to the agent:
final code = await Snaply.supportCode();
await Snaply.showSupportCode(); // …or the SDK shows it in its own sheet
```

Add the app's identifier (bundle id, package name) to each product's allowed list in the console, or
registration is refused with `origin_mismatch`.

## What is hidden

Everything is painted over **on the device, before the image is encoded** — the pixels underneath never
leave the phone. A hidden field is also locked for remote control: it takes neither a tap nor text.

| | Hidden |
|---|---|
| A field with `obscureText: true` | On its own |
| `SnaplyRedact(child: …)` | Whatever is inside; `label:` sets the caption on the box |
| A dashboard rule **by identifier** (Products → Hidden fields) | The widget under `Semantics(identifier: 'ibanField')`, or with `key: ValueKey('ibanField')` — exact match |
| A dashboard rule **by text** | A widget whose semantics label, hint or tooltip — or a field's label or hint — contains the text, in any case |

```dart
SnaplyRedact(child: TextField(controller: card)),
SnaplyRedact(label: 'ADDRESS', child: Text(address)),
Semantics(identifier: 'ibanField', child: TextField(controller: iban)),
```

Anything else on screen is captured as it is: the SDK hides password fields on its own and nothing
else. A rule by text does not look at ordinary `Text` widgets — only at labels and hints.

## Remote control

When the person allows it during a live view, the agent can tap, scroll and type. Taps and scrolls
arrive as Flutter pointer events, text goes into the focused field, Enter submits it.

## Not in this version

- **Platform views** (a map, a web view) inside the Flutter screen are not in Flutter's own image and
  come out blank.
- **The whole-screen live view** blocks the Flutter view rather than showing it.
- Web and desktop: `Snaply.configure` throws `SnaplyException('unsupported_platform')`.

## What was measured

On 2026-11-10 with the example app
(<https://github.com/Mobile-LLC/SnaplyAgent-Example-Flutter>): Flutter 3.44.8, an iOS 18.6 simulator
and an API 34 emulator, against a local Snaply backend.

| | iOS | Android |
|---|---|---|
| Starts from Dart, registers, comes online | ✓ | ✓ |
| Screenshot after consent, screen content correct | ✓ | ✓ in Flutter's default render mode |
| `obscureText` field hidden on its own | ✓ | ✓ |
| `SnaplyRedact`, with its own caption | ✓ | ✓ |
| Dashboard rule by identifier | ✓ | ✓ |
| Dashboard rule by text | ✓ | ✓ |
| Live view | ✓ | ✓ |
| Remote control — tap, scroll, type, Enter | ✓ | ✓ |
| A hidden field refuses a tap | ✓ | ✓ |
| A hidden field the person focused refuses typed text | not measured on a device (the same Dart code, unit-tested) | ✓ |
| `identify`, `reset`, `supportCode`, `showSupportCode` | ✓ | ✓ |
| Callbacks reach Dart | ✓ | ✓ |

Not measured: a physical device, and the text magnifier a person drags over a `SnaplyRedact` field.

## Develop

```
flutter analyze
flutter test
```

## Docs

<https://snaplyagent.com/docs>
