class LogWatcher < Scout::Plugin
  OPTIONS = <<-EOS
    log_path:
      default: /var/log/my.log
      name: Log path
      notes: Full path to the the log file
    service_name:
      default: MyService
      name: Service name
      notes: Name of the service - the owner of the log. Will be shown in the alert
    value_pipe:
      default: egrep "PottencialError" | egrep -v "Junk" | wc -l
      name: Value Pipe
      notes: A pipe command that goes right aftail tail #{log}
    error_pipe:
      default: egrep "PottencialError" | egrep -v "Junk" | sort | uniq -c | sort -nr
      name: Error Pipe
      notes: A pipe command that goes right aftail tail #{log} to aggregate the errors and send a notification over scout
    EOS

  METADATA = <<-EOS
    value:
      unit: /min
      precision: 2
    EOS

  def init
    @log_file_path = option("log_path").to_s.strip
    if @log_file_path.empty?
      return error( "A path to the log file wasn't provided." )
    end

    @service_name = option("service_name").to_s.strip || @log_file_path[/[^\/]+$/,0]

    @value_pipe = option("value_pipe").to_s.strip
    if @value_pipe.empty?
      return error( "The value pipe cannot be empty" )
    end

    @error_pipe = option("error_pipe").to_s.strip
    nil
  end
  
  def build_report
    return if init()
    
    last_run = memory(:last_run) || 0
    current_length = `wc -c #{@log_file_path}`.split(' ')[0].to_i
    value = 0

    # don't run it the first time
    if (last_run > 0 )
      read_length = current_length - last_run
      value  = `tail -c +#{last_run} #{@log_file_path} | head -c #{read_length} | #{@value_pipe}`.strip
      errors = `tail -c +#{last_run} #{@log_file_path} | head -c #{read_length} | #{@error_pipe}`.strip unless @error_pipe.empty?

      unless errors.to_s.empty?
        alert(build_alert(errors), "")
      end
    end
    report(:value => value)
    remember(:last_run, current_length)
  rescue Errno::ENOENT => error
    error(error.to_s)    
  end
  
  def build_alert(errors)
    subj = "Receiving errors from the #{@service_name}"
    body = errors+"\n\n"
    {:subject => subj, :body => body}
  end
  
end