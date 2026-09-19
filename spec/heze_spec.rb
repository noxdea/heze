# frozen_string_literal: true

require "tempfile"

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

  it "rejects unsupported SVG features" do
    path = Tempfile.new(["icon", ".svg"])
    path.write('<svg><filter id="blur"/></svg>')
    path.close
    expect { Heze::SVG.parse(path.path) }.to raise_error(Heze::Error, /unsupported SVG/)
  ensure
    path&.unlink
  end
end
