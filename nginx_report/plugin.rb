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
        remember(:requests, current_requests) if current_requests

        last_requests = memory(:requests)
        if (current_requests && last_requests)
          requests_sum = memory(:requests_sum) || 0
          # we had a stats reload. remember known last big value
          if ( last_requests > current_requests )
            # most likely that the stats were reset half way in between stats gathering
            current_requests=current_requests*2 
            last_requests=0

            requests_sum = requests_sum + last_requests
            remember(:requests_sum, requests_sum)
          end

          requests_total= requests_sum + current_requests
          requests_throughput = (current_requests-last_requests)/(current_time-last_run).to_f
        end
      end
    }
    remember(:last_run, current_time)
  
    report({:total => total, :reading => reading, :writing => writing, :waiting => waiting, :requests => requests, :requests_throughput => requests_throughput})
  end
end
