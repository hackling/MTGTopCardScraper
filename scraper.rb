class PostCache
  def initialize cache_dir = "post_cache"
    @cache_dir = "post_cache"
  end

  def get url, params
    key = key_for(url, params)
    cache_file = File.join @cache_dir, key
    if File.exist? cache_file
      IO.read cache_file
    else
      body = Excon.post(url, query: params).body
      File.open(cache_file, "w") { |f| f.puts body }
      body
    end
  end

  def key_for url, params
    Digest::MD5.hexdigest(url + params.to_s)
  end
end

PAGE_COUNT=1

require 'excon'
require 'nokogiri'

class MtgTop8Scraper
  BASE_URL = 'http://mtgtop8.com/topcards'
  PARAMS = {
    current_page:2,
    format:"LE",
    "metagame_sel[VI]"=>71,
    "metagame_sel[LE]"=>39,
    "metagame_sel[MO]"=>51,
    "metagame_sel[EX]"=>41,
    "metagame_sel[ST]"=>52,
    "metagame_sel[BL]"=>68,
    "metagame_sel[EDH]"=>73,
    maindeck:"MD",
  }
  FORMATS = {
    legacy: "LE",
    vintage: "VI",
    modern: "MO",
  }

  def initialize format = :legacy
    @format = FORMATS.fetch format
  end

  def cache
    @cache ||= PostCache.new
  end

  def cards start_page = 1, end_page = 10
    start_page.upto(end_page).flat_map do |page|
      page(page)
    end
  end

  def all_cards
    #puts "Precaching..."
    1.upto(page_count).map do |n|
      Thread.new do
        doc(n)
      end
    end.each &:join
    #puts "done."
    cards(1, page_count)
  end

  def page_count
    (doc(1).at('.w_title').text.split.last.to_i / 20.0).ceil
  end

  def page n
    doc(n).search("[@onclick^='AffCard']").map do |tr|
      Hash[
        [:card, :%, :count].zip tr.search("td").map(&:text)
      ]
    end
  end

  def doc n
    #puts "Scraping page #{n}"
    body = cache.get BASE_URL, PARAMS.merge(current_page: n, format: @format)
    doc = Nokogiri::HTML(body)
  end
end

require 'pp'
require 'csv'

MtgTop8Scraper::FORMATS.keys.each do |format|
  scraper = MtgTop8Scraper.new(format)
  puts "Results for #{format}"
  CSV.open("#{format}.csv", "w:ASCII-8BIT") do |csv|
    csv << %w(card % count)
    scraper.all_cards.each do |card|
      values = card.values.map { |x|
        x.encode('UTF-8', invalid: :replace)
      }
      csv << values
    end
  end
end
