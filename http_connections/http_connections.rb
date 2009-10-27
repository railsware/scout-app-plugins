class HttpConnections < Scout::Plugin

  def build_report
    data = {}
    %w( CLOSED LISTEN SYN_SENT SYN_RCVD ESTABLISHED CLOSE_WAIT LAST_ACK FIN_WAIT_1 FIN_WAIT_2 CLOSING TIME_WAIT ).each do |status|
      data.merge!({status.downcase.to_sym => netstat_count(status).strip})
    end
    report(data)
  rescue Exception => e
    error "Couldn't parse output. Make sure you have netstat installed. #{e}"
    logger.error e
  end

  private
  
  def netstat_count(state)
    lambda do
      port = option('port') || 80
      command = option('command') || "netstat -an | grep #{state} | awk '{ print $4 }' | grep -e '[:\.]#{port}$' | wc -l"
      `#{command}`
    end.call
  end

end