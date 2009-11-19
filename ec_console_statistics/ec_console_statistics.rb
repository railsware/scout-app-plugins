class EcConsoleStatistics < Scout::Plugin
  def build_report
    library_available? 'open3'
    output, error = ec_console_output
    report(output)
    error(:subject => error) unless ( error.nil? || error.empty? )
    
  rescue Exception => e
    error "Couldn't parse output. #{e}"
    logger.error e
  end

  private

  def ec_console_output
    ec_console     = option('ec_console')     || 'ec_console'
    hostname       = option('host')           || '127.0.0.1'
    port           = option('port')           || '2025'
    user           = option('user')           || 'admin'
    password       = option('password')       || ''
    command        = option('command')        || 'summary'

    cmd = %Q[#{ec_console} #{user}:#{password}@#{hostname}:#{port} #{command}]

    result ={}
    error = ""
    Open3.popen3(cmd) do |stdin, stdout, stderr|
      while out = stdout.gets
        next unless out.match(/:/)
        line = out.split(/:/)
        val = line.last.strip
        key = line.first.strip.gsub(/\s+/,'_').downcase.to_sym
        result[key] = val.to_f if val
      end
      error = stderr.gets
      error.chomp! if error
    end
    [result, error]
  end

end
