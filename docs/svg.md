---
layout: guide
title: SVG files
description: Preview and export simple static SVGs within Heze's supported subset.
---

## Start with a static icon

Save this as `mark.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg"
     width="128" height="128" viewBox="0 0 128 128">
  <rect x="8" y="8" width="112" height="112" rx="16" fill="#2563eb" />
  <path d="M32 66 L54 88 L96 40" fill="none"
        stroke="#ffffff" stroke-width="10" stroke-linecap="round" />
</svg>
```

Open a static preview, or export it without a window:

```bash
heze mark.svg --no-watch
heze mark.svg --width 256 --height 256 --theme light --export mark.png
```

The width and height options set the output viewport. The SVG's own dimensions and `viewBox` describe the artwork; Heze adds padding and the selected theme's background around it.

Use `--no-watch` for an SVG preview and reopen it after editing. The current live reload path parses changes as Markdown, so it does not provide SVG live reload. Pass SVG files directly; the directory browser lists Markdown only.

## Supported artwork

Heze uses Zaniah's static SVG renderer rather than a browser. The supported subset includes:

- Paths, rectangles, circles, ellipses, lines, polylines, and polygons.
- Groups, transforms, fills, strokes, opacity, and a root `viewBox`.
- Local definitions and `use` references such as `href="#shape"`, plus clipping paths.

Use numeric or pixel geometry and simple presentation attributes. Stylesheets and browser-specific behavior are outside this workflow.

## Rejected features and limits

Heze rejects `<filter>`, `<mask>`, `<text>`, `<linearGradient>`, and `<radialGradient>` before creating a preview. The Zaniah 0.6 renderer also rejects unsupported elements such as scripts, animation, embedded images, and `foreignObject`, along with filter, mask, dashed-stroke, and marker attributes.

Nested SVG viewports and external `use` references are unsupported. Text should be converted to paths, and gradient artwork should use solid fills before opening it in Heze.

Zaniah limits source files to 2 MiB, tree depth to 64, element count to 10,000, and an individual SVG raster to 1,048,576 pixels. Large artwork or a high display scale can exceed the raster limit even when the source is small.

For `unsupported SVG feature` or `unsupported SVG element`, simplify the source and retry with the minimal icon above. A PNG export follows the same SVG restrictions.

## Render an SVG from Ruby

```ruby
require "heze"

svg = Heze::SVG.parse("mark.svg")
renderer = Heze::Renderer.new(
  theme: Heze::Theme.resolve(:light),
  width: 256,
  height: 256
)
File.binwrite("mark.png", renderer.render(svg))
```

Return to [PNG export](export.md) for viewport options or [getting started](index.md) for installation and platform requirements.
