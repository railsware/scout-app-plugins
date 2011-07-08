# 
# This is a Scout (http://scoutapp.com) plugin that monitors nginx and 
# sends the data back to scout.
# 
# For more info, visit:
# https://scoutapp.com/plugin_urls/static/creating_a_plugin
# 
# In order to have this plugin running, you need to make sure that your 
# version of Nginx was compiled with the Stub Status module.
# 
# On Ubuntu Hardy, the nginx package comes with Stub Status compiled in so 
# if you installed Nginx via apt-get or aptitude, you should have it.
# 
# Make sure you have the following in your nginx config file:
# 
# location /nginx_status {
#   stub_status on;
#   access_log   off;
#   allow 127.0.0.1;
#   deny all;
# }
# 
# Requires "open-uri" gem
# ---- History ----

require 'open-uri'
class NginxReport < Scout::Plugin
  OPTIONS=<<-EOS
  options:
    url:
      name: Nginx Status
      notes: Default status for of nginx instance. Will reset at some point. At rotate.
      default: http://127.0.0.1/nginx_status
  metadata:
    reading:
      precision: 0
    writing:
      precision: 0
    waiting:
      precision: 0
    requests:
      precision: 0
    requests_throughput:
      units: /sec
      precision: 3

  EOS

  def build_report  
    total, requests, reading, writing, waiting = nil
    url           = option(:url) || 'http://127.0.0.1/nginx_status'
    last_run      = memory(:last_run) || Time.now.to_i
    current_time  = Time.now.to_i

    open(url) {|f|
      f.each_line do |line|
        total = $1 if line =~ /^Active connections:\s+(\d+)/
        if line =~ /^Reading:\s+(\d+).*Writing:\s+(\d+).*Waiting:\s+(\d+)/
          reading = $1
          writing = $2
          waiting = $3
        end

        if line =~ /^\s+(\d+)\s+(\d+)\s+(\d+)/
          current_requests = $3.to_i 
          last_requests = (memory(:requests) || current_requests).to_i
          # handle nginx stats reset
          current_requests = (last_requests + current_requests) if ( last_requests > current_requests )
          remember({:requests => current_requests})
          requests = (current_requests-last_requests)/(current_time-last_run).to_f
        end
      end
    }
    remember({:last_run => current_time})
  
    report({:total => total, :reading => reading, :writing => writing, :waiting => waiting, :requests => requests})
  end
end
