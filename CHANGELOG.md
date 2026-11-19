## Unreleased

Everything the SDK and Snaply's server exchange is sealed a second time inside HTTPS. The native SDKs do it and this
package brings them; its number and theirs are set the day it ships.

* `SnaplyEnvironment.custom` takes `serverKeys` — the master public keys of that server, with its address — and
  `SnaplyEnvironment.developmentMaster` is the key of a Snaply stack on your own machine. An app that talks to the
  live server changes nothing.
* Not built against the sealing native SDKs yet: the plugin code compiles only once this package brings them.

## 1.2.0

Brings the Snaply Agent iOS SDK 2.51.0 and Android SDK 2.42.0, each at exactly that version. No change to the
Dart API.

* When the app identifies a different user, the agent's console now says so: "Someone else signed in on {name}'s
  device — screenshots for this call ended." (the SDKs report the new reason `switched`; before, the console read
  "the device no longer holds the screenshot approval").
* A correction to 1.1.0's note: signing out does end an open screenshot approval — the Snaply server ends it on a
  sign-out — though the SDK itself does not.

## 1.1.0

Brings the Snaply Agent iOS SDK 2.50.0 and Android SDK 2.41.0, each at exactly that version. No change to the
Dart API.

* When the app identifies a different user (`Snaply.identify` with another id), an open screenshot approval on the
  device ends and support asks again. A live share that is already running continues. Signing out alone, a first
  sign-in and the same user signing in again change nothing.

## 1.0.1

Brings the Snaply Agent iOS SDK 2.49.1 and Android SDK 2.40.1, each at exactly that version. No change to the
Dart API.

* The consent record fixes of both SDKs: an Allow that never reached Snaply is not kept, a live session lost
  mid-way needs a new Allow, and a screenshot approval never lasts past 45 minutes.
* The iOS SDK is pinned to one version, as the Android one always was: a new SDK version reaches an app with a
  new version of this package.

## 1.0.0

The first release. Needs the Snaply Agent iOS SDK 2.48.0 and Android SDK 2.39.0, which it brings in itself.

* `Snaply.configure`, `on`, `identify`, `reset`, `supportCode`, `showSupportCode`, `stop` — from Dart, with
  no code in the iOS or Android folders.
* The agent receives the screen Flutter drew, in every Android render mode.
* Hidden on the device before the image is encoded: every `obscureText` field, anything inside
  `SnaplyRedact`, and whatever the product's dashboard rules name (a `Semantics` identifier or a
  `ValueKey<String>`; a semantics label, a field's label or hint).
* Remote control: taps, scrolling, typing, Enter and Backspace; a hidden field takes neither a tap nor text.
