# Design notes

Duo Sketch is an original design. This note records the choices so contributors keep it that way.

## Palettes

There are three frame themes. Eucalyptus is the default; ocean and ochre are chosen in the gear menu. The hex values live in `FramePalette` in SketchCore, where tests check the contrast rules below and that no colour is red.

### Eucalyptus

| Role | Colour | Hex |
| --- | --- | --- |
| Body | Eucalyptus green | `#2F5D50` |
| Body shade | Deep eucalyptus | `#23463C` |
| Body highlight | Soft eucalyptus | `#4A7A6B` |
| Drawing surface | Sand | `#EFE3C8` |
| Ink | Graphite | `#2B2B2B` |
| Dials | Brass | `#C69447` |
| Dial shade | Dark brass | `#8C6A2F` |
| Dial engraving | Dark eucalyptus | `#142A24` |

### Ocean

| Role | Colour | Hex |
| --- | --- | --- |
| Body | Deep blue-teal | `#1F4F66` |
| Body shade | Deeper teal | `#163B4D` |
| Body highlight | Soft teal | `#3B6F87` |
| Drawing surface | Pale sand | `#F2EAD8` |
| Ink | Graphite | `#2B2B2B` |
| Dials | Silver | `#C3CCD1` |
| Dial shade | Dark silver | `#7D8B94` |
| Dial engraving | Night blue | `#13232D` |

### Ochre

| Role | Colour | Hex |
| --- | --- | --- |
| Body | Burnt ochre | `#8A4A1C` |
| Body shade | Deep ochre | `#6A3612` |
| Body highlight | Soft ochre | `#A9632E` |
| Drawing surface | Cream | `#F6ECD4` |
| Ink | Graphite | `#2B2B2B` |
| Dials | Bronze | `#B98F55` |
| Dial shade | Dark bronze | `#80633A` |
| Dial engraving | Umber | `#1C130A` |

### Contrast

In every theme, ink on the surface and the wordmark on the body are at least 4.5:1, and the dial engraving is at least 3:1 at both ends of the dial gradient. For eucalyptus: graphite on sand has a contrast ratio of about 11:1, well above 4.5:1. The sand wordmark is 5.9:1 on the eucalyptus body and 8.2:1 on the deep shade. The dial pointer and arrow are a darker eucalyptus (`#142A24`): 5.6:1 on brass and 3.0:1 on dark brass, so they stay above the 3:1 needed for graphics across the whole dial gradient.

The colours are fixed, so the board looks the same in light and dark appearance, the way a physical toy would. Because nothing changes, the ratios above hold in both. `testPaletteContrastInLightAndDark` in the app tests checks every theme in both appearances.

There is no red anywhere in the frame, dials, icon or screenshots, and no grey drawing surface.

## Shape

- The body is a rounded slab with a soft diagonal gradient and a shadow. It is not a flat rectangle with a thick border.
- On iOS 26 and later the body is a `ConcentricRectangle`, so its corners follow the display corners on iPhone Duo's inner and outer screens, never tighter than 36 pt. Earlier systems get a 36 pt rounded rectangle.
- The dials are brass with engraved ticks, a dark pointer and an arrow that shows which direction each dial draws. They are not plain white knobs.
- A small "Duo Sketch" wordmark sits between the dials.

## Layouts

Layout is chosen by `BoardLayout` in SketchCore from size classes and fold posture:

- `portrait`: canvas on top, dials in the bottom corners (phones, iPhone Duo outer display)
- `landscape`: a dial on each side of the canvas
- `wide`: larger canvas and dials (iPhone Duo inner display)
- `easel`: canvas on the upper half and dials on the lower half (iPhone Duo partly open)

## App icon

The icon shows two paper panels of a folding phone, open like a book on a deep blue-teal ground, with one brass line that runs across the hinge. `scripts/make_app_icon.py` draws it. Like the frame, it has no red and borrows nothing from existing toys.
