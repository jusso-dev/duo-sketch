# Duo Sketch

A two-dial drawing toy for iPhone, built to make the most of iPhone Duo.

Turn the left dial to draw across, turn the right dial to draw up and down, and use both together for diagonals and curves. When you want a fresh page, fold the phone shut and open it again: the board gives a little shake and the drawing is gone. On any other iPhone, shake the phone instead.

Status: early development. The drawing engine and fold logic are in `Packages/SketchCore` and tested on Linux and macOS. The SwiftUI app lives in `App/`.

## Original design

Duo Sketch is an original design by Justin Middler. It is not affiliated with, endorsed by or connected to any toy company or toy brand. The name, frame, colours, dials and artwork were all designed for this project. Please keep it that way in contributions: no names, shapes, characters or colour schemes borrowed from existing toys.

## iPhone Duo features

iPhone Duo has a 5.4 inch outer display and a 7.6 inch inner display that folds. Duo Sketch uses the hinge like this:

| Pose | What happens |
| --- | --- |
| Open (inner display) | Full board: large canvas with both dials along the bottom edge. |
| Half open | Easel mode: the canvas sits on the upper half and the dials sit on the lower half, like a little desk toy. |
| Closed (outer display) | Compact board on the outer display. Your drawing carries over. |
| Closed, then opened again | The board shakes and clears, ready for a new drawing. |

Hinge data comes from Apple's public SwiftUI API in iOS 27.1, wrapped behind our own `FoldStateService` protocol so the core logic stays testable:

- [`DeviceHinge`](https://developer.apple.com/documentation/swiftui/devicehinge): `angle` and `status` (`.closed`, `.partiallyOpen`, `.fullyOpen`)
- [`DeviceHingeContext`](https://developer.apple.com/documentation/swiftui/devicehingecontext): `hinge` is `nil` on devices without a hinge
- [`View.onHingeChange(isEnabled:_:)`](https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:))
- [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/) and [Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/) (Apple Tech Talks)

Apple recommends hinge data for live effects and size classes for layout, so the layout itself follows size classes and the hinge only drives the clear gesture and easel mode.

## On other iPhones

Duo Sketch works on every iPhone that runs iOS 18 or later.

- The layout adapts to the screen with size classes.
- There is no hinge, so `DeviceHingeContext.hinge` is `nil` and the app uses the no-hinge fallback service.
- Shake the phone to clear. Each shake fades the drawing a bit more, and three good shakes clear it completely.
- There is also a Clear button in the toolbar for accessibility.

## Project layout

```
App/                      SwiftUI app (XcodeGen spec in App/project.yml)
  DuoSketch/              App sources
Packages/SketchCore/      Pure Swift package: drawing model, dial mapping,
                          clear state machine, fold service protocol and mocks
ci/workflows/             CI workflow, waiting to be moved to .github/workflows
```

## Building

### Core package (Linux or macOS)

Needs Swift 6.0 or later.

```sh
cd Packages/SketchCore
swift build
swift test
```

### App (needs a Mac)

Needs Xcode 27.1 or later (iOS 27.1 SDK, which includes the iPhone Duo simulator) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
cd App
xcodegen generate
xcrun simctl list devices available   # pick an iPhone and the iPhone Duo
xcodebuild -project DuoSketch.xcodeproj -scheme DuoSketch \
  -destination 'platform=iOS Simulator,name=<iPhone name>' build test
```

To try the fold behaviour, run the app on the iPhone Duo simulator and use the open, close and fold controls under the device.

## What needs a Mac

Everything in `Packages/SketchCore` builds and tests on Linux. These steps need macOS with Xcode:

- Generating the Xcode project (`xcodegen generate`)
- Building and testing the app target (`xcodebuild`)
- Running on the iPhone Duo simulator and checking hinge behaviour
- App Store screenshots
- Signing and TestFlight

## Licence

MIT. See [LICENSE](LICENSE). © Justin Middler
