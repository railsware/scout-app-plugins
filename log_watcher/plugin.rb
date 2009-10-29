class ScoutMysqlSlow < Scout::Plugin
  needs "elif"
  
  def initialize
    @log_file_path = option("log_path").to_s.strip
    if log_file_path.empty?
      return error( "A path to the log file wasn't provided." )
    end

    @service_name = option("service_name").to_s.strip || log_file_path[/[^\/]+$/,0]

    @pipe = option("pipe").to_s.strip
    if pipe.empty?
      return error( "A path to the log file wasn't provided." )
    end

    @error_pipe = option("error_pipe").to_s.strip
  end
  
  def build_report
    initialize
 
    last_run = memory(:last_run) || 0
    current_length = `wc -c #{@log_file_path}`.split(' ')[0].to_i

    if (last_run > 0 ) { # don't run it the first time
      read_length = current_length - last_run

      value = `tail -c #{read_length} #{@log_file_path} | #{@pipe}`.strip
      report(:value => value, :error => error_pipe)

      errors = `tail -c #{read_length} #{@log_file_path} | #{@error_pipe}`.strip unless @error_pipe.empty?
      unless errors.to_s.empty? {
        alert(build_alert(errors))
      }
    }
    remember(:last_run, current_length)
  rescue Errno::ENOENT => error
      error(error.to_s)    
  end
  
  def build_alert(errors, service)
    subj = "Receiving errors from the #{service}"
    body = String.new
    slow_queries.each do |sq|
      body << errors
      body << "\n\n"
    end
    {:subject => subj, :body => body}
  end
  
end