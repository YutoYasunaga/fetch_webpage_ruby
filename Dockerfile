FROM ruby:3.2.0 

WORKDIR /app
RUN gem i 'fileutils:1.7.0' 'net-http:0.3.2' 'nokogiri:1.10.2' 'open-uri:0.3.0' 'optparse:0.3.1'
COPY . /app

CMD ["ruby", "fetch.rb", "$@"]