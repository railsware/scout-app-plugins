class HttpConnections < Scout::Plugin

  def build_report

    response = netstat()
    data = {}
    %w( CLOSED LISTEN SYN_SENT SYN_RCVD ESTABLISHED CLOSE_WAIT LAST_ACK FIN_WAIT_1 FIN_WAIT_2 CLOSING TIME_WAIT ).each do |status|
      data.merge!({status.downcase.to_sym => netstat_count(response, status)})
    end

    report(data)

  rescue Exception => e
    error "Couldn't parse output. Make sure you have netstat installed. #{e}"
    logger.error e
  end

  private

  def netstat()
    lambda do
      port    = option('port') || 80
      netstat = option('netstat') || "netstat -an"
      awk     = option('awk') || "awk '{ print $4\" \"$6 }'"
      sort    = option('sort') || "sort | uniq -c | awk '{print $1\" \"$3}'"
      cmd     = "#{netstat} | #{awk} | grep -e '[:\.]#{port} ' | #{sort}"

      `#{cmd}`
    end.call
  end
  
  def netstat_count(response, state)
    response[/(\d+) #{state}/,1].to_i
  end
end