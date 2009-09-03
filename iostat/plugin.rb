class Iostat < Scout::Plugin
  def build_report
    # Using the second reading- avg since previous check
    output = iostat_output(device())
    values,result=values(output),{}
    [:rps, :wps, :rkbps, :wkbps, :await, :util].each{|k| result[k]=values[k]}
    report(result)
  rescue Exception => e
    error "Couldn't parse output. Make sure you have iostat installed. #{e}"
    logger.error e
    logger.error "Output: #{output}"
  end
  
  private

  def iostat_output(device)
    command = option('command') || 'iostat -dxk'
    interval = option('interval') || 5
    iostat_command = "#{command} #{interval} 2 #{device}"
    logger.info "running iostat_output for #{iostat_command}"
    `#{iostat_command}`
  end
  
  def values(output)
    # Expected output format: 
    # Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await  svctm  %util
    # xvda1             0.00     0.00    0.00    0.00     0.00     0.00     0.00     0.00    0.00   0.00   0.00 
    # take the device format fields
    #logger.info "extracting output format"
    format=output.grep(/Device:/).last.gsub(/\//,'p').gsub(/(%|:)/,'').downcase.split

    #logger.info "extracting output average values"
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