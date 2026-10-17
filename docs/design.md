# Design notes

Duo Sketch is an original design. This note records the choices so contributors keep it that way.

## Palette

| Role | Colour | Hex |
| --- | --- | --- |
| Body | Eucalyptus green | `#2F5D50` |
| Body shade | Deep eucalyptus | `#23463C` |
| Body highlight | Soft eucalyptus | `#4A7A6B` |
| Drawing surface | Sand | `#EFE3C8` |
| Ink | Graphite | `#2B2B2B` |
| Dials | Brass | `#C69447` |
| Dial shade | Dark brass | `#8C6A2F` |

Graphite on sand has a contrast ratio of about 11:1, well above 4.5:1.

There is no red anywhere in the frame, dials, icon or screenshots, and no grey drawing surface.

## Shape

- The body is a rounded slab with a soft diagonal gradient and a shadow. It is not a flat rectangle with a thick border.
- The dials are brass with engraved ticks, a dark pointer and an arrow that shows which direction each dial draws. They are not plain white knobs.
- A small "Duo Sketch" wordmark sits between the dials.

## Layouts

Layout is chosen by `BoardLayout` in SketchCore from size classes and fold posture:

- `portrait`: canvas on top, dials in the bottom corners (phones, iPhone Duo outer display)
- `landscape`: a dial on each side of the canvas
- `wide`: larger canvas and dials (iPhone Duo inner display)
- `easel`: canvas on the upper half and dials on the lower half (iPhone Duo partly open)
