require "prawn"
require "prawn/measurement_extensions"
require "active_support/core_ext/string/strip"
require "active_support/core_ext/string/filters"

class RecipePdfPresenter
  DOCUMENT_MARGIN = 0.25.in

  DOCUMENT_PAGE_SIZE = [6.in, 4.in]

  DEFAULT_FONT_FAMILY = "DejaVuSansMono"
  DEFAULT_FONT_SIZE = 8
  DEFAULT_FONT_LEADING = 1

  COLUMNS = {
    ingredients: {
      position: [0, 230],
      dimensions: {
        width: 2.6125.in,
        height: 240
      },
    },
    directions: {
      position: [2.8875.in, 230],
      dimensions: {
        width: 2.6125.in,
        height: 240
      },
    },
  }

  FONT_MANIFEST = {
    "DejaVuSansMono" => {
      bold:        "_fonts/DejaVuSansMono-Bold.ttf",
      bold_italic: "_fonts/DejaVuSansMono-BoldOblique.ttf",
      italic:      "_fonts/DejaVuSansMono-Oblique.ttf",
      normal:      "_fonts/DejaVuSansMono.ttf",
    }
  }

  attr_reader :filename, :content

  def self.generate_all!(pages)
    pages.each do |page|
      new(page: page).tap do |generator|
        generator.to_pdf
        generator.cleanup!
      end
    end
  end

  def initialize(page:)
    @filename = page.destination("/").sub(/\.html\z/, ".pdf")
    @content  = File.read(page.path, **Jekyll::Utils.merged_file_read_opts(page.site, {}))
  end

  def ingredients
    @ingredients ||= begin
                       found = false
                       lines = []
                       content.lines.each do |l|
                         if found && l =~ /\A## /
                           break
                         end

                         if found && l.chomp != ""
                           lines << l.chomp.sub(/\A[-\*] /, "")
                         end

                         if l.chomp =~ /\A## Ingredients\z/
                           found = true
                         end
                       end
                       parse_markdown_emphasis lines.join("\n")
                     end
  end

  def directions
    @directions ||= begin
                      found = false
                      lines = []
                      content.lines.each do |l|
                        if found
                          lines << l.chomp
                        end
                        if l.chomp =~ /\A## Directions\z/
                          found = true
                        end
                      end
                      out = lines.join("\n").strip.gsub(/\n\n/, "XXX").squish.gsub("XXX", "\n\n")
                      parse_markdown_emphasis out
                    end
  end

  def title
    @title ||= begin
                 line = content.lines.first {|l| l =~ /\A# /}
                 line.chomp[2..-1]
               end
  end

  def to_pdf
    opts = { page_size: DOCUMENT_PAGE_SIZE, margin: DOCUMENT_MARGIN }

    Prawn::Document.generate(filename, opts) do |pdf|
      pdf.font_families.update(FONT_MANIFEST)
      pdf.font DEFAULT_FONT_FAMILY, size: DEFAULT_FONT_SIZE

      pdf.text title, style: :bold
      pdf.default_leading DEFAULT_FONT_LEADING

      COLUMNS.each do |name, col|
        pdf.bounding_box(col[:position], col[:dimensions]) do
          pdf.text name.to_s.capitalize, style: :bold
          pdf.move_down 10
          pdf.text send(name), inline_format: true
        end
      end
    end


  end

  def cleanup!
    md = filename.sub(/\.pdf\z/, ".md")
    txt = filename.sub(/\.pdf\z/, ".txt")
    File.rename(md, txt)
  end

  private

  def parse_markdown_emphasis(string)
    string.gsub(/^### (.*)$/, "\n<b>\\1</b>").strip

  end
end


Jekyll::Hooks.register :site, :post_write do |site|
  recipes = site.pages.select { |page| page.data["recipe"] }

  RecipePdfPresenter.generate_all!(recipes)
end
