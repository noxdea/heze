---
layout: guide
title: Previewing documents
description: Browse Markdown files, reload edits, and choose a preview backend or theme.
---

## Open a file or directory

Open a Markdown document from an interactive terminal:

```bash
heze notes.md
heze "project notes/overview.md"
```

Open a directory to browse its Markdown files:

```bash
heze docs/
```

Heze recursively finds lowercase `.md` files, sorts their paths, and opens the first file. Select a filename in the sidebar to preview another document. Only the selected document is watched. The file list is collected when the preview opens; restart Heze after adding files to the directory.

Scroll the document area to read content below the visible window. Heze is a previewer: edit the source in your usual text editor.

## Reload saved edits

Interactive previews watch the opened document automatically. Save a change in your editor to refresh the preview. If the selected file disappears or cannot be loaded, the preview displays an error.

For a single file, disable live reload with:

```bash
heze notes.md --no-watch
```

In the current directory browser, selecting a different file starts a watcher for that file even when the preview was opened with `--no-watch`.

`--watch` is useful outside an interactive preview. For example, print update notifications without a window:

```bash
heze notes.md --backend headless --watch
```

Press Ctrl+C to stop watching. When watching a directory outside a preview, only its first sorted Markdown file is watched. To refresh a PNG on each save, see [watched exports](export.md#refresh-an-export-on-save). For SVG files, use the [static SVG workflow](svg.md).

## Choose a backend

| Option | Behavior |
| --- | --- |
| `--backend auto` | Default: macOS, Windows, or Linux native preview according to the platform |
| `--backend mac` | Native macOS preview |
| `--backend linux` | Native Linux preview |
| `--backend windows` | Native Windows preview |
| `--backend tui` | Interactive terminal rendering |
| `--backend headless` | A path summary; no preview window |

Run the terminal backend from an interactive terminal:

```bash
heze notes.md --backend tui
```

Noninteractive output prints a summary regardless of the requested preview backend. PNG [exports](export.md) always use the headless renderer.

## Set the size and theme

```bash
heze notes.md --width 1000 --height 700 --theme light
```

The defaults are width `900`, height `1000`, and theme `dark`. Built-in themes are `dark`, `light`, and `high_contrast`.

When the optional [Auva](https://github.com/noxdea/auva) gem is available, `--theme path/to/tokens.json` can load an Auva theme file. Without Auva, use a built-in name. An invalid name produces `unknown theme`.

## What Markdown looks like

Heze parses GitHub Flavored Markdown and renders a simplified document view:

- Headings retain their `#` markers; ordered and unordered lists become text with numbers or bullets.
- Quotes receive a border, and fenced code blocks use syntax highlighting when a lexer is available.
- Inline emphasis and code are flattened to text. Links show their label followed by the URL rather than acting as browser links.
- Markdown images inside paragraphs appear as text such as `[image: diagram]`. Heze does not fetch remote images.
- Tables are parsed, but the current table renderer can show a **Preview error** placeholder. Do not rely on table layout for an export.

The preview does not apply a web page's HTML or CSS styling. It displays at most the first 50,000 top-level document nodes.

Continue with [PNG export](export.md), or return to [getting started](index.md).
