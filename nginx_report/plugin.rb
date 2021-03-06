require 'open-uri'

class NginxReport < Scout::Plugin

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
