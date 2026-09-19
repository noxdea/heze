<h1 align="center">Heze</h1>

<p align="center">
  <strong>Headless Markdown and SVG previewer with deterministic PNG export.</strong>
</p>

<p align="center">
  <a href="https://rubygems.org/gems/heze"><img src="https://img.shields.io/gem/v/heze?style=flat-square" alt="Gem version"></a>
  <a href="https://rubygems.org/gems/heze"><img src="https://img.shields.io/gem/dt/heze?style=flat-square" alt="Gem downloads"></a>
  <a href="https://github.com/noxdea/heze/actions/workflows/main.yml"><img src="https://github.com/noxdea/heze/actions/workflows/main.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/Ruby-%3E%3D%203.2-CC342D?style=flat-square" alt="Ruby 3.2 or newer">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="MIT license"></a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#cli">CLI</a> ·
  <a href="#ruby-api">Ruby API</a> ·
  <a href="#development">Development</a>
</p>

---

Heze is a headless Markdown and SVG previewer with deterministic PNG export.
It keeps the parsed document tree independent from the renderer, then uses
[Zaniah](https://github.com/noxdea/zaniah) for native previews and image output.

## Features

- **GitHub Flavored Markdown** — headings, lists, quotes, tables, fenced code, links, and images.
- **Validated SVG input** — unsupported filters, masks, text, and gradients fail before rendering.
- **Deterministic PNGs** — export the same document at an explicit width and height.
- **Native preview** — automatic macOS, Linux, and Windows backends with a textual fallback.
- **Live reload** — watch a document while editing, or browse a directory of Markdown files.
- **Syntax highlighting** — fenced code blocks are highlighted through Antares and Rouge.
- **Encoding detection** — UTF-8 BOM and Japanese Windows-31J input are handled safely.

## Installation

```bash
gem install heze
```

Heze requires Ruby 3.2 or newer.

## Quick start

Open a native preview:

```bash
heze README.md
```

Export a deterministic PNG:

```bash
heze README.md --width 1200 --height 800 --export preview.png
```

Pass a directory to browse its Markdown files:

```bash
heze docs/
```

## CLI

```text
Usage: heze PATH [options]
```

| Option | Description | Default |
|---|---|---|
| `--export PATH` | Write a PNG instead of opening a preview | — |
| `--width N` | Preview or export width | `900` |
| `--height N` | Preview or export height | `1000` |
| `--theme NAME` | Select a named theme | `dark` |
| `--backend NAME` | `auto`, `headless`, `tui`, `mac`, `linux`, or `windows` | `auto` |
| `--watch` | Watch for changes outside an interactive preview | off |
| `--no-watch` | Disable interactive live reload | off |

Static SVG files use the same preview and export flow:

```bash
heze assets/mark.svg --export mark.png
```

## Ruby API

Parse Markdown into an immutable document tree and render it directly:

```ruby
require "heze"

document = Heze::Markdown.parse("# Hello\n\nRendered by Heze.")
png = Heze::Renderer.new(width: 1200, height: 630).render(document)
File.binwrite("preview.png", png)
```

## Development

```bash
bundle install
bundle exec rake
bundle exec rbs -I sig validate
gem build --strict heze.gemspec
```

## Contributing

Bug reports and pull requests are welcome on
[GitHub](https://github.com/noxdea/heze).

## License

Heze is available under the [MIT License](LICENSE.txt).
