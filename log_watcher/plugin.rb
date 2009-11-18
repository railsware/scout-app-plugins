class LogWatcher < Scout::Plugin
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

      value = `tail -c #{read_length} #{@log_file_path} | #{@value_pipe}`.strip

      errors = `tail -c #{read_length} #{@log_file_path} | #{@error_pipe}`.strip unless @error_pipe.empty?
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