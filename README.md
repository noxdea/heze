# Heze

Headless Markdown/SVG preview parsing for the noxdea toolchain. Heze keeps the
document tree independent from the renderer and exports deterministic PNGs.

## Installation

```sh
gem install heze
```

## Usage

```sh
heze README.md --export preview.png
heze docs/ --width 1200 --height 800 --export preview.png
heze README.md --backend headless --no-watch
```

`Heze::Markdown.parse` returns an immutable document tree. SVG input is
validated before being handed to Zaniah. Headings, paragraphs, lists, quotes,
tables, fenced code, links, images, and horizontal rules are preserved in the
preview tree; unsupported nodes remain visible as plain text. Native preview
falls back to a textual view when the platform backend is unavailable.

## Development

Run `rake spec` and `gem build --strict heze.gemspec`.

## Contributing

Bug reports and pull requests are welcome at https://github.com/noxdea/heze.

## License

MIT.
