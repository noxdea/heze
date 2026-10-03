---
layout: guide
title: PNG export
description: Export a fixed-size viewport from the command line or Ruby.
---

## Export from the command line

```bash
heze notes.md --export notes.png --width 1200 --height 800 --theme light
```

`--export` writes a PNG instead of opening a preview. Export works without a graphical desktop and does not require `--backend headless`.

| Option | Default | Effect |
| --- | --- | --- |
| `--export PATH` | None | Write the image to this path |
| `--width N` | `900` | Image width in pixels |
| `--height N` | `1000` | Image height in pixels |
| `--theme NAME` | `dark` | Use `dark`, `light`, or `high_contrast` |

Use positive integer dimensions. The output is a fixed viewport, not a paginated or automatically fitted document; content below its height is outside the image. Increase the height or shorten the document when necessary.

An existing output file is overwritten. Create the destination directory before exporting there. When the input is a directory, Heze exports its first sorted Markdown file without the browser sidebar; pass a specific file to choose another document.

The renderer produces repeatable bytes for the same input, dimensions, theme, and rendering environment. Fonts and installed dependency versions can affect results across machines.

## Refresh an export on save

```bash
heze notes.md --export notes.png --width 1200 --height 800 --watch
```

Heze creates the initial PNG, then overwrites it when the Markdown file changes. It prints `heze: updated notes.md` after a successful refresh. Press Ctrl+C to stop. Watching a directory tracks only its first sorted Markdown file.

Use a one-time export for [SVG files](svg.md); the current reload path parses changes as Markdown.

## Render from Ruby

Save this as `export.rb` and run `ruby export.rb`:

```ruby
require "heze"

document = Heze::Markdown.parse("# Hello\n\nRendered by Heze.")
renderer = Heze::Renderer.new(
  theme: Heze::Theme.resolve(:light),
  width: 1200,
  height: 630
)
File.binwrite("preview.png", renderer.render(document))
```

`render` returns PNG bytes. Without options, `Heze::Renderer.new` uses the dark theme and a `900 × 1000` viewport, matching the CLI defaults.

To read a source file through Heze's encoding detection and supply its directory for local image paths:

```ruby
path = File.expand_path("notes.md")
document = Heze::Markdown.parse(Heze::Source.read(path))
png = renderer.render(document, base_path: File.dirname(path))
File.binwrite("notes.png", png)
```

The same [Markdown rendering limits](preview.md#what-markdown-looks-like) apply to the Ruby API. Continue with [SVG files](svg.md), or return to [previewing documents](preview.md).
