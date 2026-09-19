# frozen_string_literal: true

require "tempfile"
require "fileutils"
require "stringio"

RSpec.describe Heze do
  it "maps Markdown headings and paragraphs" do
    document = Heze::Markdown.parse("# Title\n\nHello **world**")
    expect(document.children.map(&:type)).to include(:header, :p)
    expect(document.children.first.text).to eq("# Title")
  end

  it "parses fenced code blocks in GFM mode" do
    document = Heze::Markdown.parse("```ruby\nputs 1\n```")
    expect(document.children.first.type).to eq(:codeblock)
    expect(document.children.first.text).to include("puts 1")
    expect(Heze::Highlight.tokens(document.children.first)).not_to be_empty
  end

  it "keeps list, quote, and table structure visible in preview text" do
    document = Heze::Markdown.parse("- one\n- two\n\n> quote\n\n| a | b |\n|---|---|\n| c | d |")
    text = document.children.map(&:text).join("\n")
    expect(text).to include("• one", "│ quote", "c | d")
  end

  it "rejects unsupported SVG features" do
    path = Tempfile.new(["icon", ".svg"])
    path.write('<svg><filter id="blur"/></svg>')
    path.close
    expect { Heze::SVG.parse(path.path) }.to raise_error(Heze::Error, /unsupported SVG/)
  ensure
    path&.unlink
  end

  it "tolerates a deleted watched file" do
    dir = Dir.mktmpdir("heze-watch")
    path = File.join(dir, "doc.md")
    File.write(path, "# title\n")
    watcher = Heze::Watcher.new(path)
    File.unlink(path)
    expect { watcher.poll }.not_to raise_error
    expect(watcher.error).to be_a(Heze::Error)
  ensure
    FileUtils.remove_entry(dir) if dir
  end

  it "rejects unknown preview backends" do
    dir = Dir.mktmpdir("heze-backend")
    path = File.join(dir, "doc.md")
    File.write(path, "# title\n")
    err = StringIO.new
    expect(Heze::CLI.run([path, "--backend", "nonsense"], out: StringIO.new, err: err)).to eq(1)
    expect(err.string).to include("unknown backend")
  ensure
    FileUtils.remove_entry(dir) if dir
  end

  it "renders structured Markdown as a deterministic PNG" do
    document = Heze::Markdown.parse("# Title\n\n```ruby\nputs 1\n```\n\n> quote")
    first = Heze::Renderer.new(width: 320, height: 240).render(document)
    second = Heze::Renderer.new(width: 320, height: 240).render(document)
    expect(first.byteslice(0, 8)).to eq("\x89PNG\r\n\x1a\n".b)
    expect(second).to eq(first)
  end

  it "resolves Markdown images relative to the source file" do
    dir = Dir.mktmpdir("heze-images")
    FileUtils.mkdir_p(File.join(dir, "assets"))
    File.binwrite(File.join(dir, "assets", "dot.png"), Zaniah::PNG.encode(1, 1, "\xff\x00\x00\xff".b))
    path = File.join(dir, "doc.md")
    File.write(path, "![dot](assets/dot.png)\n")
    document = Heze::Markdown.parse(Heze::Source.read(path))
    expect(Heze::Renderer.new(width: 160, height: 120).render(document, base_path: dir)).to start_with("\x89PNG".b)
  ensure
    FileUtils.remove_entry(dir) if dir
  end

  it "decodes Japanese Windows-31J Markdown" do
    dir = Dir.mktmpdir("heze-encoding")
    path = File.join(dir, "doc.md")
    File.binwrite(path, "# 日本語の見出し\n".encode("Windows-31J"))
    expect(Heze::Source.read(path)).to include("日本語の見出し")
  ensure
    FileUtils.remove_entry(dir) if dir
  end
end
