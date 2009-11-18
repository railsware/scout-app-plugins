require 'open-uri'

class NginxReport < Scout::Plugin

  def build_report  
    url = option(:url) || 'http://127.0.0.1/nginx_status'

    total, requests, reading, writing, waiting = nil

    current_time = Time.now.to_i
    last_run = memory(:last_run)

    open(url) {|f|
      f.each_line do |line|
        total = $1 if line =~ /^Active connections:\s+(\d+)/
        if line =~ /^Reading:\s+(\d+).*Writing:\s+(\d+).*Waiting:\s+(\d+)/
          reading = $1
          writing = $2
          waiting = $3
        end

        current_requests = $3.to_i if line =~ /^\s+(\d+)\s+(\d+)\s+(\d+)/
        if (current_requests)
          last_requests = memory(:requests)
          remember(:requests, current_requests)
          requests = (current_requests-last_requests)/(current_time-last_run) if last_requests && last_run
          puts "requests #{requests}, last_requests:#{last_requests}, current_requests:#{current_requests}, current_time:#{current_time}, last_run:#{last_run}"
        end
      end
    }
    remember(:last_run, current_time)
  
    report({:total => total, :reading => reading, :writing => writing, :waiting => waiting, :requests => requests})
  end
end
