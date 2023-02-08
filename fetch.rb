# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'nokogiri'
require 'open-uri'

class WebpageCrawler
  SOURCE_FOLDER = 'sources'
  ERROR_MAX_LENGTH = 100

  def initialize(uri)
    @uri = URI.parse(uri.chomp('/'))
  end

  def fetch
    puts "\nFetching #{@uri}..."

    source = get_html(@uri)
    contents = Nokogiri::HTML(source)
    @img_tags, @js_tags, @css_tags = get_asset_tags(contents)
    save_contents(contents)

    puts '✅ Done'
  rescue StandardError => e
    puts "❌ Error while fetching #{@uri}: #{e.message}"
  end

  private

  # Get HTML from URL
  def get_html(url)
    res = Net::HTTP.get_response(url)
    # If response code is redirect, update the URL to the location header of the response
    url = URI.parse(res['location']) if %w[301 302 307].include?(res.code)

    Net::HTTP.get url
  end

  # Get all asset tags
  def get_asset_tags(contents)
    img_tags = contents.xpath('//img[@src]')
    js_tags = contents.xpath('//script[@src]', '//link[@as="script"]')
    css_tags = contents.xpath('//link[@rel="stylesheet"]')

    [img_tags, js_tags, css_tags]
  end

  # Save contents (assets and result html file)
  def save_contents(contents)
    # Create source folder if it doesn't exists
    FileUtils.mkdir_p(SOURCE_FOLDER) unless Dir.exist?(SOURCE_FOLDER)

    # Create source folder of specific web page to contain assets, recreate it if exists
    file_name = "#{@uri.host}#{@uri.path}.html".tr('/', '_')
    @source_path = "#{SOURCE_FOLDER}/#{file_name.sub('.html', '')}"
    FileUtils.rm_rf(@source_path) if Dir.exist?(@source_path)
    FileUtils.mkdir_p(@source_path)

    save_asset(@img_tags, "#{@source_path}/images")
    save_asset(@js_tags, "#{@source_path}/js")
    save_asset(@css_tags, "#{@source_path}/css")

    # Write content to result file
    File.open(file_name, 'w') do |file|
      file.write(contents.to_html)
    end
  end

  # Save asset
  def save_asset(tags, dir)
    tags.each do |tag|
      localize_asset(tag, dir)
    rescue StandardError => e
      puts "One asset failed to save to #{dir}: #{e.message[0...ERROR_MAX_LENGTH]}"
      next
    end
  end

  # Download asset and update the URL in tag
  def localize_asset(tag, dir)
    attribute = tag[:src] ? :src : :href
    url = tag[attribute]
    asset_url = url_for(url)
    destination = localize_url(url, dir)
    download_asset(asset_url, destination)
    tag[attribute.to_s] = "#{@source_path}/" + destination.partition(File.dirname(dir) + File::SEPARATOR).last
  end

  # Convert a URL to a local file path
  def localize_url(url, dir)
    path = url.gsub(%r{^[|[:alpha]]+://}, '') # Remove URL scheme
    path.gsub!(%r{^[./]+}, '') # Remove leading '/'
    path.gsub!(%r{[^-_./[:alnum:]]}, '_') # Remove any characters that are not in "-_./[:alnum] with underscores"

    File.join(dir, path)
  end

  # Retrieve the URL of a resource
  def url_for(str)
    return str if str =~ %r{^[|[:alpha:]]+://} # Return if str start with URL scheme

    File.join(@uri.path.empty? ? @uri.to_s : File.dirname(@uri.to_s), str)
  end

  # Download asset
  def download_asset(asset_url, destination)
    FileUtils.mkdir_p File.dirname(destination)
    uri = URI.parse(asset_url)
    return unless uri

    data = get_html(uri)
    File.open(destination, 'wb') { |f| f.write(data) } if data
  end
end

# Loop all arguments from command line and fetch web page
ARGV.each do |url|
  WebpageCrawler.new(url).fetch
end
