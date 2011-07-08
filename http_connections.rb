# Network Statistics Plugin
# =================================
# Created by [Dmitry Larkin](http://github.com/dml)
#
# Reports the current network tcp status for defined port
#
# Dependencies
# ------------
# Requires the netstat, awk, grep
#
# Compatibility 
# -------------

class HttpConnections < Scout::Plugin
  OPTIONS=<<-EOS
  options:
    port:
      name: monitoring Port
      notes: By default 80 port is used
      default: 80
    netstat:
      name: netstat Command
      notes: The command used to collect network connections
      default: netstat -an
    awk:
      name: awk script
      notes: This script used to grab results column
      default: awk '{ print $4" "$6 }'
    sort:
      name: sort script
      notes: will be used to sort and group
      default: sort | uniq -c | awk '{print $1" "$3}'



  metadata:
    closed:
      label: CLOSED
      precision: 0
    listen:
      label: LISTEN
      precision: 0
    syn_sent:
      label: SYN_SENT
      precision: 0
    syn_rcvd:
      label: SYN_RCVD
      precision: 0
    established:
      label: ESTABLISHED
      precision: 0
    close_wait:
      label: CLOSE_WAIT
      precision: 0
    last_ack:
      label: LAST_ACK
      precision: 0
    fin_wait_1:
      label: FIN_WAIT_1
      precision: 0
    fin_wait_2:
      label: FIN_WAIT_2
      precision: 0
    closing:
      label: CLOSING
      precision: 0
    time_wait:
      label: TIME_WAIT
      precision: 0



  triggers: 
  - max_value: 10000
    type: peak
    dname: established

  EOS
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