## 1.0.0

The first release. Needs the Snaply Agent iOS SDK 2.48.0 and Android SDK 2.39.0, which it brings in itself.

* `Snaply.configure`, `on`, `identify`, `reset`, `supportCode`, `showSupportCode`, `stop` — from Dart, with
  no code in the iOS or Android folders.
* The agent receives the screen Flutter drew, in every Android render mode.
* Hidden on the device before the image is encoded: every `obscureText` field, anything inside
  `SnaplyRedact`, and whatever the product's dashboard rules name (a `Semantics` identifier or a
  `ValueKey<String>`; a semantics label, a field's label or hint).
* Remote control: taps, scrolling, typing, Enter and Backspace; a hidden field takes neither a tap nor text.
