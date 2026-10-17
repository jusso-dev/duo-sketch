# App Store screenshots

The screenshots come from a UI test, `App/DuoSketchUITests/ScreenshotTests.swift`. It launches the app on fixed demo drawings and saves one image per shot:

| File | Shot | Launch arguments |
| --- | --- | --- |
| `1-blank-board.png` | Blank board | `-demoDrawing blank` |
| `2-finished-drawing.png` | Finished drawing (skyline) | `-demoDrawing skyline` |
| `3-easel-mode.png` | Half-open easel mode | `-demoDrawing spiral -foldPosture easel` |
| `4-shake-clear.png` | Shake clear, mid animation | `-demoDrawing hills -holdShake`, then tap Clear |
| `5-share-sheet.png` | Share sheet | `-demoDrawing skyline`, then Share, Share with frame |

The demo drawings (spiral, hills and skyline) are in `Packages/SketchCore/Sources/SketchCore/DemoDrawings.swift`. They are original and drawn with dial moves only. Demo launches don't read or write the saved drawing, and `-foldPosture` fixes the fold pose so easel mode can be captured on any simulator.

## Regenerating

On a Mac with Xcode 27.1 or later and XcodeGen:

```sh
scripts/screenshots.sh
```

This runs the screenshot tests on a 6.9 inch iPhone (`iPhone 17 Pro Max`) and on `iPhone Duo`, sets a clean status bar, and writes the images to `Screenshots/<device>/`. Pass simulator names to pick other devices:

```sh
scripts/screenshots.sh "iPhone 18 Pro Max"
```

CI also exports them. Every run uploads a `Screenshots` artifact from the simulator it tested on (an iPhone Duo when the runtime has one). A manual run (Actions, iOS, Run workflow) adds the newest Pro Max iPhone too. A manual run also pushes every image to the `ci-screenshots` branch, so you can browse them on GitHub or `git fetch origin ci-screenshots`.

## iPhone Duo outer display

The tests capture whichever display the simulator shows, which is the inner display when the device is open. For the outer display shots, use the fold controls under the iPhone Duo simulator to close it, then run `scripts/screenshots.sh "iPhone Duo"` again and move the images into `Screenshots/iphone-duo-outer/`.

## Before uploading

Open each image at full size. Check there are no debug overlays, the status bar reads 9:41, and the drawing isn't clipped.
