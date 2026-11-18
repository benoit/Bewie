# Bewie app icon

The active icon is `Bewie/AppIcon.icon`, a native layered Icon Composer document,
used by the iOS, Catalyst and Watch targets. Xcode compiles the adaptive icon.

- Default and dark: original logo colors and texture on chalk `#F2F1EC`.
  Chalk is explicitly retained in dark mode so the original dark logo stays visible.
- The Default/Dark logo has no fill, mask tint or inversion: its original RGB and
  alpha are rendered directly. A separate image specialization supplies clear and
  tinted modes with a brighter monochrome source, retaining the source texture.
  It maps luminance to `0.55 + 0.45 * sqrt(luminance)` and preserves alpha, rather
  than replacing the textured logo with a solid silhouette.
- Apple's Mono annotation serves both clear and tinted light/dark. Their actual
  hue/material remains system-controlled; purple in the exports is a sample tint.
- The original 243 × 180 PNG is byte-for-byte unchanged and retained at
  `Design/Logo/Bewie-original.png`, from the album website's `logo.png`.
- Centered foreground at 3.2× native image size (about 76% of the 1024-point width),
  with subtle native shadow/translucency. No rounded tile or glass effects are
  baked into the foreground image. Square and watchOS circular platforms enabled.

All six appearances are rendered for design generations 26 and 27 under
`Design/Icons/iOS-26` and `Design/Icons/iOS-27`. These PNGs are previews; the live
`.icon` document supplies the system's adaptive appearance. Clear exports use
Icon Composer's neutral preview environment rather than an actual wallpaper.

Regenerate native exports and the comparison sheet:

```sh
swift tools/prepare-mono-logo.swift
python3 tools/export-icon-previews.py
swift tools/make-icon-contact-sheet.swift
```

All 12 iPhone/iPad/Messages marketing icon sizes composite the original colored logo on chalk.
The stickers icon catalog requires flat opaque images, so these are generated
separately by drawing its original RGB and alpha, without a solid-color mask:

```sh
swift tools/generate-messages-icons.swift
```

The inherited pearl icon is archived at `Design/Icons/InheritedPearl.icon`, outside
the build target. The separate private pearl/map asset is preserved. tvOS uses matching original-color Bewie foreground/chalk background layers, generated
with `swift tools/generate-tv-icons.swift`. Top Shelf and the album launch cover retain the album artwork.

Validation: all twelve native previews rendered; all six iOS 27 previews visually
reviewed; matching Messages marketing icon visually reviewed. iOS Simulator and
Catalyst builds compile the new icon; the iOS build includes the Watch icon and
all twelve Messages icon slots. Compiled asset metadata is retained at
`build/icon-assets-info.json` and summarized in `Documentation/IconVerification.json`.

Apple references:
- https://developer.apple.com/icon-composer/
- https://developer.apple.com/videos/play/wwdc2025/361/

Tinted-dark contrast revision: Default/Dark preview PNGs verified byte-for-byte
unchanged after adding the Mono image specialization. Comparison is retained at
`Design/Icons/TintedDark-comparison.png`. The original logo source and Messages
assets remain unchanged by this revision.
