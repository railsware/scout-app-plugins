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
  		requests = $3/(current_time-last_run) if line =~ /^\s+(\d+)\s+(\d+)\s+(\d+)/ && last_run
  	  end
  	}
  	remember(:last_run, current_time)
	
	  report({:total => total, :reading => reading, :writing => writing, :waiting => waiting, :requests => requests})
  end
end
