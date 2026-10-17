# Duo Sketch

A two-dial drawing toy for iPhone, built to make the most of iPhone Duo.

Turn the left dial to draw across, turn the right dial to draw up and down, and use both together for diagonals and curves. When you want a fresh page, fold the phone shut and open it again: the board gives a little shake and the drawing is gone. On any other iPhone, shake the phone instead.

Status: early development. The drawing engine and fold logic are in `Packages/SketchCore` and tested on Linux. The SwiftUI app lives in `App/`. CI builds it and runs its tests on a hosted macOS runner for every pull request (`.github/workflows/ios.yml`), but it hasn't been tried on a real iPhone Duo yet. Design notes are in [docs/design.md](docs/design.md).

## Original design

Duo Sketch is an original design by Justin Middler. It is not affiliated with, endorsed by or connected to any toy company or toy brand. The name, frame, colours, dials and artwork were all designed for this project. Please keep it that way in contributions: no names, shapes, characters or colour schemes borrowed from existing toys.

## iPhone Duo features

iPhone Duo has a 5.4 inch outer display and a 7.6 inch inner display that folds. Duo Sketch uses the hinge like this:

| Pose | What happens |
| --- | --- |
| Open (inner display) | Full board: large canvas with both dials along the bottom edge. |
| Half open (20 to 160 degrees) | Easel mode: the canvas sits on the upper half and the dials sit on the lower half, like a little desk toy. |
| Closed (outer display) | Compact board on the outer display. Your drawing carries over. |
| Closed for at least 0.4 s, then opened again to 20 degrees or more | The board shakes and clears, ready for a new drawing. For a few seconds afterwards, Undo clear in the toolbar brings the drawing back. A hinge settling by a degree or two after closing doesn't count as opening. |

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
- Shake the phone to clear. Each shake fades the drawing a bit more, and three good shakes clear it completely. Shakes less than half a second apart count once.
- There is also a Clear button in the toolbar for accessibility, with a few seconds of Undo after it clears.

## Sharing and settings

- Share offers the drawing with its frame or on its own, as a PNG at 3x with an SVG as the second format. It also offers the replay as a short video. Everything is made on the phone, and nothing leaves it unless you share it.
- Replay (the play button) draws the picture again in the order you made it, over eight seconds. The dials rest while it plays.
- Hold a dial still for a moment to switch it to fine gearing: a quarter of the travel per turn, for detail work. A small engraved dot marks a dial in fine gearing. Hold again to switch back. VoiceOver users get a custom action for the same thing.
- The gear menu has:
  - Haptics on or off: dial ticks, edge bumps and the clear pattern. They also follow the system setting.
  - Frame: eucalyptus, ocean or ochre.
  - Preview on external display: when the phone is connected to a TV or monitor, or AirPlaying, the drawing shows there live for anyone watching.
- With Reduce Motion on, the board doesn't shake when it clears. The drawing fades out instead, and Replay is off.

### About the outer display

The external display preview uses Apple's scene accessory API (`sceneAccessory` with `ExternalNonInteractiveAccessory`). Apple doesn't offer iPhone Duo's own outer display to apps through this API, except for camera capture (`CameraCaptureAccessory`), so a drawing app can't mirror the board onto the back of the phone.

### Checking fold poses

Launch with `-foldDebug` to show the current fold posture and hinge angle on the board. On the iPhone Duo simulator, use the open, close and fold controls under the device and watch the overlay.

## Project layout

```
App/                      SwiftUI app (XcodeGen spec in App/project.yml)
  DuoSketch/              App sources
Packages/SketchCore/      Pure Swift package: drawing model, dial mapping,
                          clear state machine, fold service protocol and mocks
.github/workflows/ios.yml CI: SketchCore tests, then the app build and tests on
                          an iOS 27 simulator (pull requests and pushes to main)
```

## Building

### Core package (Linux or macOS)

Needs Swift 6.2 or later.

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
- App Store screenshots (`scripts/screenshots.sh`, see [docs/screenshots.md](docs/screenshots.md))
- Signing and TestFlight

## Licence

MIT. See [LICENSE](LICENSE). © Justin Middler
