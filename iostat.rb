# Improved IO Statistics Plugin
# =================================
# Created by [Yaroslav Lazor](http://github.com/yaroslavlazor)
# 
# Reports the following IO staticics : rps, wps, rkbps, wkbps, await, util
# Configurable per device or the device mounted to root partition.
# 
# Dependencies
# ------------
# Requires the iostat command, usually provided by the sysstat package.
# 
# Compatibility 
# -------------
# 
# Works on Linux and OSX. 


class Iostat < Scout::Plugin
  OPTIONS=<<-EOS
  options:
    command:
      name: iostat Command
      notes: The command used to display IO statistics
      default: "iostat -dxk"
    interval:
      name: iostat Interval
      notes: Report current usage as the average over this many seconds.
      default: 5 
    device:
      name: Device
      notes: The device to check, eg 'sda1'. If not specified, last one from iostat -dxk
      default:      
  metadata:
    rps:
      label: Reads/sec
    wps:
      label: Writes/sec
    rkbps:
      label: Read kBps
      units: kB/s
    wkbps:
      label: Write kBps
      units: kB/s
    await:
      label: I/O Wait
      units: ms
    svctm:
      label: Service Time
      units: ms
    util:
      label: Utilization
      units: %

  triggers:
    - type: peak
      dname: util
      max_value: 80%
  EOS

  def build_report
    # Using the second reading- avg since previous check
    output = iostat_output(device())
    values,result=values(output),{}
    [:rps, :wps, :rkbps, :wkbps, :await, :util].each{|k| result[k]=values[k]}
    report(result)
  rescue Exception => e
    error "Couldn't parse output. Make sure you have iostat installed. #{e}"
    # log.error e
    # log.error "Output: #{output}"
  end
  
  private

  def iostat_output(device)
    command = option('command') || 'iostat -dxk'
    interval = option('interval') || 5
    iostat_command = "#{command} #{interval} 2 #{device}"
    # log.info "running iostat_output for #{iostat_command}"
    `#{iostat_command}`
  end
  
  def values(output)
    # Expected output format: 
    # Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await  svctm  %util
    # xvda1             0.00     0.00    0.00    0.00     0.00     0.00     0.00     0.00    0.00   0.00   0.00 
    # take the device format fields
    # log.info "extracting output format"
    format=output.grep(/Device:/).last.gsub(/\//,'p').gsub(/(%|:)/,'').downcase.split

    # log.info "extracting output average values"
    # take all the stat fields
    raw_stats=output.split("\n").grep(/[0-9]+\.[0-9]+$/).last.split

    # count average
    stats={}
    format.each_with_index { |field,i| stats[ format[i].to_sym ]=raw_stats[i] }
    stats
  end
  
  def device
    root_dev=`mount`.grep(/ \/ /)[0].split[0].split('/').last
    option('device') || "#{root_dev} #{root_dev.gsub(/[0-9]/,'')}"
  end  
end