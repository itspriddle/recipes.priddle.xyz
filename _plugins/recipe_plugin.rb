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
                        if found && l.chomp != "---"
                          lines << l.chomp
                        end
                        if l.chomp =~ /\A## Directions\z/
                          found = true
                        elsif l.chomp == "---"
                          break
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

  def extra
    @extra ||= begin
                 found = false
                 lines = []
                 content.lines.each do |l|
                   if found
                     lines << l.chomp
                   end

                   if l.chomp == "---"
                     found = true
                   end
                 end
                 out = lines.join("\n").strip.gsub(/\n\n/, "XXX").squish.gsub("XXX", "\n\n")
                 parse_markdown_emphasis out
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

      if extra.chomp != ""
        pdf.start_new_page
        pdf.text extra
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
    string
      .gsub(/^### (.*)$/, "\n<b>\\1</b>")
      .gsub(/\*\*([^\*]+)\*\*/, "<b>\\1</b>")
      .strip
  end
end


Jekyll::Hooks.register :site, :post_write do |site|
  recipes = site.pages.select { |page| page.data["recipe"] }

  RecipePdfPresenter.generate_all!(recipes)
end

module Jekyll
  module Drops
    class StaticFileDrop
      def recipe_title
        return unless fallback_data["recipe"]

        p = File.expand_path("../..#{path}", __FILE__)

        File.open(p, &:gets).sub(/\A# /, "")
      end
    end
  end
end

class OldUrlRewrite
  REDIRECT_TEMPLATE = <<~HTML
    <!DOCTYPE html>
    <html lang="en-US">
      <meta charset="utf-8">
      <title>Redirecting&hellip;</title>
      <link rel="canonical" href="{URL}">
      <script>location="{URL}"</script>
      <meta http-equiv="refresh" content="0; url={URL}">
      <meta name="robots" content="noindex">
      <h1>Redirecting&hellip;</h1>
      <a href="{URL}">Click here if you are not redirected.</a>
    </html>
  HTML

  URLS = {
    "6 Layer Taco Dip.html"                 => "6-layer-taco-dip.html",
    "Anginetti Italian Cookies.html"        => "anginetti-italian-cookies.html",
    "Ants Climbing Trees.html"              => "ants-climbing-trees.html",
    "Artisan Bread.html"                    => "artisan-bread.html",
    "Baked Egg Rolls.html"                  => "baked-egg-rolls.html",
    "Baked Mac and Cheese.html"             => "baked-mac-and-cheese.html",
    "Baked Ziti.html"                       => "baked-ziti.html",
    "Banana Bread.html"                     => "banana-bread.html",
    "Beef Stew.html"                        => "beef-stew.html",
    "Bourbon Street Chicken.html"           => "bourbon-street-chicken.html",
    "Buffalo Chicken Dip.html"              => "buffalo-chicken-dip.html",
    "Buffalo Chicken Garbage Bread.html"    => "buffalo-chicken-garbage-bread.html",
    "Buffalo Chicken Pull-Apart Bread.html" => "buffalo-chicken-pull-apart-bread.html",
    "Buffalo Chicken Rolls.html"            => "buffalo-chicken-rolls.html",
    "Cajun Roasted Potato Wedges.html"      => "cajun-roasted-potato-wedges.html",
    "Cheese Souffle.html"                   => "cheese-souffle.html",
    "Chicken Noodle Soup.html"              => "chicken-noodle-soup.html",
    "Chocolate Chip Cookies.html"           => "chocolate-chip-cookies.html",
    "Cinnamon Butter.html"                  => "cinnamon-butter.html",
    "Classic Cheesecake.html"               => "classic-cheesecake.html",
    "Fettuccine Carbonara.html"             => "fettuccine-carbonara.html",
    "Fresh Pasta.html"                      => "fresh-pasta.html",
    "Italian Meatballs.html"                => "italian-meatballs.html",
    "Italian Wedding Soup.html"             => "italian-wedding-soup.html",
    "Jack Daniel's Sauce.html"              => "jack-daniels-sauce.html",
    "Jalapeno Cheddar Bread.html"           => "jalapeno-cheddar-bread.html",
    "Justin's Autumn Fruit Chicken.html"    => "justins-autumn-fruit-chicken.html",
    "Kahlua Cheesecake.html"                => "kahlua-cheesecake.html",
    "Lemon Garlic Roasted Chicken.html"     => "lemon-garlic-roasted-chicken.html",
    "Lo Mein.html"                          => "lo-mein.html",
    "Milk Bread.html"                       => "milk-bread.html",
    "Parmesan Crisps.html"                  => "parmesan-crisps.html",
    "Pasta Fagioli.html"                    => "pasta-fagioli.html",
    "Pasta Salad.html"                      => "pasta-salad.html",
    "Pecan Pie.html"                        => "pecan-pie.html",
    "Pot Sticker Sauce.html"                => "pot-sticker-sauce.html",
    "Pot Stickers.html"                     => "pot-stickers.html",
    "Pumpkin Cheesecake Bars.html"          => "pumpkin-cheesecake-bars.html",
    "Roasted Chickpeas.html"                => "roasted-chickpeas.html",
    "Sauteed Fresh Green Beans.html"        => "sauteed-fresh-green-beans.html",
    "Simple Fruit Syrup.html"               => "simple-fruit-syrup.html",
    "Southwest Pasta Salad.html"            => "southwest-pasta-salad.html",
    "Spicy Chili Cheese Dip.html"           => "spicy-chili-cheese-dip.html",
    "Spicy Hummus.html"                     => "spicy-hummus.html",
    "Spinach Artichoke Dip.html"            => "spinach-artichoke-dip.html",
    "Stuffed Shells.html"                   => "stuffed-shells.html",
    "Turkey Chili.html"                     => "turkey-chili.html",
    "Vincenzos Marinara Sauce.html"         => "vincenzos-marinara-sauce.html",
  }

  def self.generate(site)
    URLS.each do |old_url, new_url|
      path = File.expand_path("../../_site/recipes/#{old_url}", __FILE__)

      next if File.exist?(path)

      File.open(path, "w") do |f|
        f.puts REDIRECT_TEMPLATE.gsub("{URL}", "#{site.config["url"]}/recipes/#{new_url}")
      end
    end
  end
end

Jekyll::Hooks.register :site, :post_write do |site|
  OldUrlRewrite.generate(site)
end
