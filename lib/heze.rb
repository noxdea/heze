# frozen_string_literal: true

require "optparse"
require "antares"
require "kramdown"
require "zaniah"
begin
  require "auva"
rescue LoadError
end
begin
  require "menkar"
rescue LoadError
  # The fallback keeps the parser useful while an optional local Menkar checkout is used.
end
require_relative "heze/version"

module Heze
  class Error < StandardError; end
  Node = Data.define(:type, :text, :children, :attributes)

  module Source
    module_function

    def read(path)
      bytes = File.binread(path)
      if defined?(Menkar)
        detection = Menkar.detect(bytes)
        raise Error, "binary input: #{path}" if detection.binary
        return Menkar.decode(bytes, detection)
      end
      bytes.force_encoding(Encoding::UTF_8)
      raise Error, "invalid UTF-8 input: #{path}" unless bytes.valid_encoding?
      bytes
    rescue Errno::ENOENT
      raise Error, "file not found: #{path}"
    end
  end

  module Markdown
    module_function

    def parse(text)
      document = Kramdown::Document.new(text, input: "GFM")
      Node.new(type: :document, text: nil, children: document.root.children.map { |node| map(node) }, attributes: {})
    rescue StandardError => error
      raise Error, "markdown parse failed: #{error.message}"
    end

    def map(node)
      children = node.children.map { |child| map(child) }
      text = case node.type
      when :text, :codeblock, :codespan then node.value.to_s
      when :a then "#{inline_text(node)} (#{node.attr["href"]})"
      when :img then "[image: #{node.attr["alt"] || node.attr["src"]}]"
      when :header then "#{"#" * node.options.fetch(:level, 1)} #{inline_text(node)}"
      when :ul then node.children.map { |child| "• #{inline_text(child)}" }.join("\n")
      when :ol then node.children.map.with_index { |child, index| "#{index + 1}. #{inline_text(child)}" }.join("\n")
      when :blockquote then node.children.map { |child| "│ #{inline_text(child)}" }.join("\n")
      when :table
        node.children.flat_map { |section| section.children }.map { |row| row.children.map { |cell| inline_text(cell) }.join(" | ") }.join("\n")
      when :hr then "---"
      when :blank then ""
      when :li, :p, :td, :th then inline_text(node)
      else inline_text(node)
      end
      attributes = node.attr.dup
      attributes["language"] = node.options[:lang] if node.type == :codeblock && node.options[:lang]
      Node.new(type: node.type, text: text, children: children, attributes: attributes)
    end

    def inline_text(node)
      return node.value.to_s if node.children.empty? && node.respond_to?(:value)
      node.children.map { |child| map(child).text.to_s }.join
    end
    private_class_method :inline_text
  end

  module Highlight
    module_function

    def tokens(node)
      return [] unless node&.type == :codeblock
      require "antares"
      require "rouge"
      lexer = Rouge::Lexer.find_fancy(node.attributes["language"].to_s)
      lines = node.text.to_s.lines
      highlighter = Antares::Highlighter.new(lexer: lexer, lines: ->(index) { lines[index] }, line_count: -> { lines.length })
      highlighter.tokens_in(0...lines.length)
    rescue LoadError, Rouge::Guesser::Ambiguous
      node.text.to_s.lines.map { |line| [[nil, line]] }
    rescue StandardError
      node.text.to_s.lines.map { |line| [[nil, line]] }
    end
  end

  module SVG
    module_function

    def parse(path)
      source = File.binread(path)
      raise Error, "unsupported SVG feature: #{Regexp.last_match(1)}" if source.match(/<(filter|mask|text|linearGradient|radialGradient)\b/i)
      Zaniah::SVG.open(path)
    rescue ArgumentError => error
      raise Error, error.message
    rescue Errno::ENOENT
      raise Error, "SVG file not found: #{path}"
    end
  end

  module Theme
    module_function

    def resolve(value)
      return value if value.respond_to?(:colors)
      return Auva.load(value) if defined?(Auva) && File.file?(value.to_s)
      return Auva.builtin(value) if defined?(Auva)
      Zaniah::Theme.public_send(value.to_s)
    rescue NoMethodError
      raise Error, "unknown theme: #{value}"
    end
  end

  module Directory
    module_function

    def markdown(path) = Dir[File.join(path, "**/*.md")].sort
  end

  class Renderer
    def initialize(theme: Zaniah::Theme.dark, width: 900, height: 1000)
      @theme, @width, @height = theme, width, height
      @font_db = Zaniah::TextSystem::FontDB.new(paths: [])
      @font = @font_db.find(family: theme.typography.font_sans)
      @text_system = Zaniah::TextSystem::Renderer.new(font: @font, font_db: @font_db)
    rescue StandardError
      @font_db = @font = @text_system = nil
    end

    def render(document)
      window = Zaniah::Platform.open_window(backend: :headless, width: @width, height: @height)
      window.text_system = @text_system if @text_system
      window.draw do
        if document.is_a?(Zaniah::SVG)
          Zaniah::Div.new.p(32).bg(@theme.colors.background).child(document)
        else
          lines = flatten(document).first(160)
          element = Zaniah::Div.new.flex_col.p(32).gap(10).bg(@theme.colors.background)
          lines.each { |line| element = element.child(Zaniah::Text.new(line, size: line.start_with?("#") ? 28 : 18, color: @theme.colors.text)) }
          element
        end
      end
      window.tick
      device = window.device
      Zaniah::PNG.encode(device.width.to_i, device.height.to_i, device.pixels)
    ensure
      window&.close
    end

    private

    def flatten(node)
      return [] unless node
      return node.children.flat_map { |child| flatten(child) } if node.type == :document
      [node.text].compact
    end
  end

  class Watcher
    def initialize(path, latency: 0.1)
      @path, @latency, @last, @event_at = path, latency, (File.mtime(path) rescue nil), 0.0
      @watch = defined?(Zaniah::Platform) && Zaniah::Platform.watch(File.dirname(path), latency: latency)
    end

    def poll
      events = @watch ? @watch.poll(timeout: 0) : []
      changed = events.any? { |event| File.expand_path(event.path) == File.expand_path(@path) }
      changed ||= File.file?(@path) && File.mtime(@path) != @last
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return false if changed && now - @event_at < @latency
      @event_at = now if changed
      @last = File.mtime(@path) if changed && File.file?(@path)
      changed
    rescue Errno::ENOENT
      false
    end
  end

  class CLI
    def self.run(argv, out: $stdout, err: $stderr)
      options = {export: nil, width: 900, height: 1000, theme: :dark, backend: :auto}
      OptionParser.new do |opts|
        opts.banner = "Usage: heze PATH [options]"
        opts.on("--export PATH") { |v| options[:export] = v }
        opts.on("--width N", Integer) { |v| options[:width] = v }
        opts.on("--height N", Integer) { |v| options[:height] = v }
        opts.on("--theme NAME") { |v| options[:theme] = v }
        opts.on("--backend NAME") { |v| options[:backend] = v.to_sym }
        opts.on("--no-watch") { options[:no_watch] = true }
        opts.on("--watch") { options[:watch] = true }
      end.parse!(argv)
      path = argv.fetch(0)
      document = if File.directory?(path)
        first = Directory.markdown(path).first or raise Error, "no Markdown files in #{path}"
        Markdown.parse(Source.read(first))
      elsif File.extname(path).downcase == ".svg"
        SVG.parse(path)
      else
        Markdown.parse(Source.read(path))
      end
      if options[:export]
        bytes = if document.is_a?(Zaniah::SVG)
          Renderer.new(theme: Theme.resolve(options[:theme]), width: options[:width], height: options[:height]).render(document)
        else
          Renderer.new(theme: Theme.resolve(options[:theme]), width: options[:width], height: options[:height]).render(document)
        end
        File.binwrite(options[:export], bytes)
      else
        out.puts "heze: #{path} (#{document.type if document.respond_to?(:type)})"
        Directory.markdown(path).each { |entry| out.puts "  #{entry}" } if File.directory?(path)
      end
      watch = options[:watch] || (!options[:no_watch] && !options[:export] && out.tty?)
      watch(path, options, out: out, err: err) if watch
      0
    rescue OptionParser::ParseError, KeyError, Error => error
      err.puts "heze: #{error.message}"
      1
    end

    def self.watch(path, options, out:, err:)
      target = File.directory?(path) ? Directory.markdown(path).first : path
      return unless target
      watcher = Watcher.new(target)
      loop do
        sleep 0.1
        next unless watcher.poll
        begin
          document = Markdown.parse(Source.read(target))
          if options[:export]
            png = Renderer.new(theme: Theme.resolve(options[:theme]), width: options[:width], height: options[:height]).render(document)
            File.binwrite(options[:export], png)
          end
          out.puts "heze: updated #{target}"
        rescue StandardError => error
          err.puts "heze: #{error.message}"
        end
      end
    rescue Interrupt
      out.puts "heze: stopped"
    end
    private_class_method :watch
  end
end
