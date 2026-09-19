# frozen_string_literal: true

require "optparse"
require "pathname"
require "antares"
require "kramdown"
require "kramdown-parser-gfm"
require "zaniah"
require "zaniah/ui"
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

    def render(document, base_path: nil)
      window = Zaniah::Platform.open_window(backend: :headless, width: @width, height: @height)
      window.text_system = @text_system if @text_system
      window.draw { element(document, base_path: base_path).first }
      window.tick
      device = window.device
      Zaniah::PNG.encode(device.width.to_i, device.height.to_i, device.pixels)
    ensure
      window&.close
    end

    def show(document, backend: :auto, title: "Heze", watcher: nil, loader: nil, files: nil, selected_path: nil)
      selected = backend == :auto ? (RUBY_PLATFORM.include?("darwin") ? :mac : RUBY_PLATFORM.match?(/mswin|mingw/) ? :windows : :linux) : backend
      window = Zaniah::Platform.open_window(backend: selected, width: @width, height: @height, title: title)
      window.text_system = @text_system if @text_system
      current = document
      error = nil
      current_path = selected_path
      scroll_view = nil
      load_document = lambda do |path|
        loader.parameters.empty? ? loader.call : loader.call(path)
      end if loader
      window.draw do
        offset = scroll_view&.scroll_state&.offset
        view, next_scroll_view = element(current, files: files, selected_path: current_path,
          base_path: current_path && File.dirname(current_path), on_select: lambda do |path|
          begin
            current = load_document.call(path)
            current_path = path
            watcher = Watcher.new(path)
            error = nil
          rescue StandardError => load_error
            error = load_error
          end
          window.request_frame
        end)
        next_scroll_view.scroll_state.offset = offset if offset && next_scroll_view
        scroll_view = next_scroll_view
        error ? view.child(Zaniah::Text.new("heze: #{error.message}", size: 16, color: @theme.colors.danger)) : view
      end
      window.on_tick do
        next unless watcher&.poll
        if watcher.error
          error = watcher.error
        elsif loader
          begin
            current = load_document.call(current_path)
            error = nil
          rescue StandardError => load_error
            error = load_error
          end
        end
        window.request_frame
      end
      window.run
    ensure
      window&.close
    end

    private

    def element(document, files: nil, selected_path: nil, base_path: nil, on_select: nil)
      if document.is_a?(Zaniah::SVG)
        root = Zaniah::Div.new.p(32).bg(@theme.colors.background).child(document)
        [root, nil]
      else
        nodes = document.children.first(50_000)
        scroll = Zaniah::List.new(count: nodes.length, estimated_height: 40) do |index|
          Zaniah::Div.new.p([7, 0]).child(render_node(nodes[index], base_path: base_path))
        end.flex_1
        return [Zaniah::Div.new.flex_col.bg(@theme.colors.background).child(scroll), scroll] unless files&.any?

        sidebar = Zaniah::UI::Sidebar.new(width: 240)
        files.each do |path|
          variant = path == selected_path ? :secondary : :ghost
          sidebar.child(Zaniah::UI::Button.new(File.basename(path), size: :sm, variant: variant).w_full
            .on_click { on_select&.call(path) })
        end
        [Zaniah::Div.new.flex_row.bg(@theme.colors.background).child(sidebar).child(scroll), scroll]
      end
    end

    def render_node(node, base_path: nil)
      case node.type
      when :header
        size = {1 => :xl, 2 => :lg, 3 => :md}.fetch(node.attributes.fetch("level", 3).to_i, :sm)
        Zaniah::UI::Label.new(node.text.to_s, size: size, wrap: :word)
      when :codeblock
        runs = Highlight.tokens(node).flat_map { |line| line.map { |token, text| {text: text, color: syntax_color(token)} } }
        Zaniah::UI::Card.new(Zaniah::UI::Label.new(node.attributes["language"] || "code", tone: :muted, size: :xs),
          Zaniah::UI::RichText.new(runs, selectable: false))
      when :blockquote
        Zaniah::Div.new.flex_row.gap(10).border(1).border_color(@theme.colors.accent).p(12)
          .child(Zaniah::UI::Label.new(node.text.to_s, wrap: :word))
      when :table
        rows = node.text.to_s.lines.map { |line| line.chomp.split(" | ") }
        columns = rows.first.to_a.each_index.map { |index| {key: index, label: "", width: 160, sortable: false, resizable: false} }
        Zaniah::UI::Table.new(rows.map { |row| row.each_with_index.to_h }, columns: columns, height: [rows.length * 32 + 40, 120].max,
          selection: :none)
      when :hr
        Zaniah::UI::Divider.new
      when :img
        path = node.attributes["src"].to_s
        path = File.expand_path(path, base_path) if base_path && !Pathname.new(path).absolute?
        File.file?(path) ? Zaniah::Image.new(path) : Zaniah::UI::EmptyState.new("Image unavailable", message: path)
      else
        Zaniah::UI::Label.new(node.text.to_s, wrap: :word)
      end
    rescue StandardError => error
      Zaniah::UI::EmptyState.new("Preview error", message: error.message)
    end

    def syntax_color(token)
      shortname = token.respond_to?(:shortname) ? token.shortname.to_s : ""
      case shortname
      when /k|c/ then @theme.colors.text_muted
      when /nb|nc|nf|n/ then @theme.colors.accent
      when /s|dl/ then @theme.colors.success
      when /m|mi|mf/ then @theme.colors.warning
      else @theme.colors.text
      end
    end
  end

  class Watcher
    attr_reader :error

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
      @error = nil if changed
      changed
    rescue Errno::ENOENT
      changed = @error.nil?
      @error = Error.new("file not found: #{@path}")
      changed
    rescue StandardError => error
      @error = error
      false
    end
  end

  class CLI
    BACKENDS = %i[auto headless tui mac linux windows].freeze

    def self.run(argv, out: $stdout, err: $stderr)
      options = {export: nil, width: 900, height: 1000, theme: :dark, backend: :auto}
      OptionParser.new do |opts|
        opts.banner = "Usage: heze PATH [options]"
        opts.on("--export PATH") { |v| options[:export] = v }
        opts.on("--width N", Integer) { |v| options[:width] = v }
        opts.on("--height N", Integer) { |v| options[:height] = v }
        opts.on("--theme NAME") { |v| options[:theme] = v }
        opts.on("--backend NAME") do |value|
          backend = value.to_sym
          raise Error, "unknown backend: #{value}" unless BACKENDS.include?(backend)
          options[:backend] = backend
        end
        opts.on("--no-watch") { options[:no_watch] = true }
        opts.on("--watch") { options[:watch] = true }
      end.parse!(argv)
      path = argv.fetch(0)
      document_path = if File.directory?(path)
        Directory.markdown(path).first or raise Error, "no Markdown files in #{path}"
      elsif File.extname(path).downcase == ".svg"
        path
      else
        path
      end
      document = File.extname(document_path).downcase == ".svg" ? SVG.parse(document_path) : Markdown.parse(Source.read(document_path))
      if options[:export]
        bytes = Renderer.new(theme: Theme.resolve(options[:theme]), width: options[:width], height: options[:height]).render(
          document, base_path: File.dirname(File.expand_path(document_path))
        )
        File.binwrite(options[:export], bytes)
      elsif out.tty? && options[:backend] != :headless
        begin
          target = File.directory?(path) ? Directory.markdown(path).first : path
          files = File.directory?(path) ? Directory.markdown(path) : nil
          watcher = options[:no_watch] || !target ? nil : Watcher.new(target)
          loader = target && ->(selected = target) { Markdown.parse(Source.read(selected)) }
          Renderer.new(theme: Theme.resolve(options[:theme]), width: options[:width], height: options[:height]).show(
            document, backend: options[:backend], title: "Heze — #{File.basename(path)}", watcher: watcher, loader: loader,
            files: files, selected_path: target
          )
        rescue StandardError => error
          err.puts "heze: native preview unavailable: #{error.message}"
          out.puts "heze: #{path} (#{document.type if document.respond_to?(:type)})"
        end
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
            png = Renderer.new(theme: Theme.resolve(options[:theme]), width: options[:width], height: options[:height]).render(
              document, base_path: File.dirname(File.expand_path(target))
            )
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
