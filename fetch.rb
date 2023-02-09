# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'nokogiri'
require 'optparse'
require 'open-uri'

# Define class for webpage crawler
class WebpageCrawler
  SOURCE_FOLDER = 'sources'
  LOG_FOLDER = 'logs'
  ERROR_MAX_LENGTH = 100

  def initialize(uri)
    @uri = URI.parse(uri.chomp('/'))
  end

  # Fetch and get page meta data
  def fetch_and_get_metadata
    source = get_html(@uri)
    contents = Nokogiri::HTML(source)

    puts "\nsite: #{@uri}".green
    puts "num_links: #{count_links(contents)}".green
    puts "images: #{count_images(contents)}".green
    puts "last_fetched: #{last_fetch}".green

    save_logs
  rescue StandardError => e
    puts "❌ Error while fetching #{@uri}: #{e.message}".red
  end

  # Fetch and download page
  def fetch_and_download
    puts "\nFetching #{@uri}...".green

    source = get_html(@uri)
    contents = Nokogiri::HTML(source)
    @img_tags, @js_tags, @css_tags = get_asset_tags(contents)
    save_contents(contents)
    save_logs

    puts '✅ Done'.green
  rescue StandardError => e
    puts "❌ Error while fetching #{@uri}: #{e.message}".red
  end

  private

  # Get HTML from URL
  def get_html(uri)
    res = Net::HTTP.get_response(uri)
    # If response code is redirect, update the URL to the location header of the response
    url = %w[301 302 307].include?(res.code) ? URI.parse(res['location']) : uri

    Net::HTTP.get url
  end

  # Get all asset tags
  def get_asset_tags(contents)
    img_tags = contents.xpath('//img[@src]')
    js_tags = contents.xpath('//script[@src]', '//link[@as="script"]')
    css_tags = contents.xpath('//link[@rel="stylesheet"]')

    [img_tags, js_tags, css_tags]
  end

  # Count links
  def count_links(contents)
    contents.xpath('//a[@href]').count
  end

  # Count images
  def count_images(contents)
    contents.xpath('//img[@src]').count
  end

  # Save contents (assets and result html file)
  def save_contents(contents)
    # Create source folder if it doesn't exists
    FileUtils.mkdir_p(SOURCE_FOLDER) unless Dir.exist?(SOURCE_FOLDER)

    # Create source folder of specific webpage to contain assets, recreate it if exists
    @source_path = "#{SOURCE_FOLDER}/#{file_name}"
    FileUtils.rm_rf(@source_path) if Dir.exist?(@source_path)
    FileUtils.mkdir_p(@source_path)

    save_asset(@img_tags, "#{@source_path}/images")
    save_asset(@js_tags, "#{@source_path}/js")
    save_asset(@css_tags, "#{@source_path}/css")

    # Write content to result file
    File.open("#{file_name}.html", 'w') do |file|
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

  # Save logs
  def save_logs
    # Create log folder if it doesn't exists
    FileUtils.mkdir_p(LOG_FOLDER) unless Dir.exist?(LOG_FOLDER)

    File.open("#{LOG_FOLDER}/#{file_name}.txt", 'a+') do |file|
      file.write("#{Time.now.utc.strftime("%a %b %d %Y %H:%M UTC")}\n")
    end
  end

  # Get file_name of fetched page
  def file_name
    "#{@uri.host}#{@uri.path}".tr('/', '_')
  end

  # Get last fetched time
  def last_fetch
    file = "#{LOG_FOLDER}/#{file_name}.txt"
    result = File.open(file, 'r') { |f| f.readlines.last } if File.exist?(file)
    result || 'N/A'
  end
end

# Add methods to print colored string to terminal
class String
  def red
    "\e[31m#{self}\e[0m"
  end

  def green
    "\e[32m#{self}\e[0m"
  end
end

# Get page urls and options from arguments
options = {}
pages = OptionParser.new do |parser|
  parser.on("--metadata", "Show metadata") do |v|
    options[:metadata] = v
  end
end.parse!

# Loop all page urls from arguments and run task
if options[:metadata]
  pages.each { |page| WebpageCrawler.new(page).fetch_and_get_metadata }
else 
  pages.each { |page| WebpageCrawler.new(page).fetch_and_download }
end
