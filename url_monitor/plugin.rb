require 'benchmark'
require 'net/http'
require 'net/https'
require 'uri'

class UrlMonitor < Scout::Plugin
  include Net

  TEST_USAGE = "#{File.basename($0)} url URL last_run LAST_RUN"
  TIMEOUT_LENGTH = 50 # seconds

  def build_report
    urls = option("url").to_s.strip
    if urls.empty?
      return error("A url wasn't provided.")
    end
    urls.split(";").each do |u|
        check_url(u)
    end
  end

  def valid_http_response?(result)
    [HTTPOK,HTTPFound].include?(result.class)
  end

  # returns the http response (string) from a url
  def http_response(url)
    uri = URI.parse(url)

    response = nil
    retry_url_trailing_slash = true
    retry_url_execution_expired = true
    begin
      http = Net::HTTP.new(uri.host,uri.port)
      http.use_ssl = url =~ %r{\Ahttps://}
      http.start(){|http|
            http.open_timeout = TIMEOUT_LENGTH
            req = Net::HTTP::Get.new((uri.path != '' ? uri.path : '/' ) + (uri.query ? ('?' + uri.query) : ''))
            if uri.user && uri.password
              req.basic_auth uri.user, uri.password
            end
            response = http.request(req)
      }
    rescue Exception => e
      # forgot the trailing slash...add and retry
      if e.message == "HTTP request path is empty" and retry_url_trailing_slash
        url += '/'
        uri = URI.parse(url)
        h = Net::HTTP.new(uri.host)
        retry_url_trailing_slash = false
        retry
      elsif e.message =~ /execution expired/ and retry_url_execution_expired
        retry_url_execution_expired = false
        retry
      else
        response = e.to_s
      end
    end

    return response
  end

  def unindent(string)
    indentation = string[/\A\s*/]
    string.strip.gsub(/^#{indentation}/, "")
  end

  def check_url(url)
    url.to_s.strip
    unless url =~ %r{\Ahttps?://}
      url = "http://#{url}"
    end
    def url.wu(s)
      "#{s}_#{self}".to_sym
      end
    #wx#u = Proc.new {|s| (s + "_" + url).to_sym  } 
    response = nil
    response_time = Benchmark.realtime do
      response = http_response(url)
    end
    response_status = response.class.to_s[/^Net::HTTP(.*)$/, 1]

    report(:status => response_status,
           :response_time => response_time)

    is_up = valid_http_response?(response) ? 1 : 0
    report(url.wu("up") => is_up)

    was_up_key=url.wu("was_up")
    down_at_key=url.wu("down_at")
    if is_up == 0
      unless memory(down_at_key)
        alert( "The URL [#{url}] is not responding",
               "URL: #{url}\n\nStatus: #{response_status}. ")
        remember(down_at_key => Time.now)
      else
        alert( "The URL [#{url}] is still not responding",
               "URL: #{url}\n\nStatus: #{response_status}. " +
               "Is unresponsive for #{(Time.now - memory(down_at_key)).to_i} seconds")
      end
    elsif is_up != memory(was_up_key)
      unless (memory(was_up_key) && memory(down_at_key))
        alert( "The URL [#{url}] is responding",
               "URL: #{url}\n\nStatus: #{response_status}. ")
      else
        alert( "The URL [#{url}] is responding again",
               "URL: #{url}\n\nStatus: #{response_status}. " +
               "Was unresponsive for #{(Time.now - memory(down_at_key)).to_i} seconds")
      end
      memory.delete(down_at_key)
    end
    remember(was_up_key => is_up)
  rescue Exception => e
    error( "Error monitoring url [#{url}]",
           "#{e.message}<br><br>#{e.backtrace.join('<br>')}" )
  end
end



