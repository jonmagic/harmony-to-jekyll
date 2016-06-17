require "httparty"
require "nokogiri"
require "pandoc-ruby"
require "pry"

class HarmonyToJekyll
  def initialize(year)
    @year = year
  end

  attr_reader :year

  def perform
    post_links.each(&method(:convert_and_write))
  end

  def post_links
    response = HTTParty.get("http://theprogrammingbutler.com/blog/archives/#{year}/")
    archive = Nokogiri::HTML(response.body)
    archive.xpath("//article/h2/a").map {|t| t.attribute("href").text }
  end

  def convert_and_write(link)
    response = HTTParty.get(link)
    post = Nokogiri::HTML(response.body)
    title = post.xpath("//article/h2").text.gsub(/\sTweet\z/, "")
    dashed_title = /\/([^\/]+)\/\z/.match(link)[1]
    timestamp = Time.parse(/posted\s(.*)\sby Hoyt/.match(post.search("//article").children[-2])[1])
    body = []
    post.search("//article").children[2..-3].each_with_index do |el, i|
      line = el.text.strip
      next if line == ""

      body << el.to_html
    end
    converter = PandocRuby.new(body.join("\n"), :from => :html, :to => :markdown)

    File.open(filename(timestamp, dashed_title), "w") do |file|
      file.write(header(title))
      file.write(converter.convert)
    end
  end

  def header(title)
<<-TEXT
---
layout: post
title: #{title}
---

TEXT
  end

  def filename(timestamp, dashed_title)
    "#{timestamp.strftime('%F')}-#{dashed_title}.md"
  end
end

(2006..2014).each do |year|
  HarmonyToJekyll.new(year).perform
end
