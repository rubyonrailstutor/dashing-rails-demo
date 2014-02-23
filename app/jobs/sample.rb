current_valuation = 0

Dashing.scheduler.every '2s' do
  last_valuation = current_valuation
  current_valuation = rand(100)

  Dashing.send_event('valuation', { current: current_valuation, last: last_valuation })
  Dashing.send_event('synergy',   { value: rand(100) })
end

require 'net/http'
require 'uri'
require 'nokogiri'
require 'htmlentities'

# https://gist.github.com/toddq/5422482
# https://github.com/Shopify/dashing/wiki/Additional-Widgets

news_feeds = {
  "seattle-times" => "http://seattletimes.com/rss/home.xml",
}

Decoder = HTMLEntities.new

class News
  def initialize(widget_id, feed)
    @widget_id = widget_id
    # pick apart feed into domain and path
    uri = URI.parse(feed)
    @path = uri.path
    @http = Net::HTTP.new(uri.host)
  end

  def widget_id()
    @widget_id
  end

  def latest_headlines()
    response = @http.request(Net::HTTP::Get.new(@path))
    doc = Nokogiri::XML(response.body)
    news_headlines = [];
    doc.xpath('//channel/item').each do |news_item|
      title = clean_html( news_item.xpath('title').text )
      summary = clean_html( news_item.xpath('description').text )
      news_headlines.push({ title: title, description: summary })
    end
    news_headlines
  end

  def clean_html( html )
    html = html.gsub(/<\/?[^>]*>/, "")
    html = Decoder.decode( html )
    return html
  end

end

@News = []
news_feeds.each do |widget_id, feed|
  begin
    @News.push(News.new(widget_id, feed))
  rescue Exception => e
    puts e.to_s
  end
end

Dashing.scheduler.every '5s' do
  @News.each do |news|
    headlines = news.latest_headlines()
    Dashing.send_event(news.widget_id, { :headlines => headlines })
  end
end