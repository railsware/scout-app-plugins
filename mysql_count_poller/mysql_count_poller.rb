class MysqlCountPoller < Scout::Plugin
  def build_report
    library_available? 'open3'    
    report(query_output)
    
  rescue Exception => e
    error "Couldn't parse output. Make sure you have proper SQL. #{e}"
    logger.error e
  end

  private

  def query_output
    mysql     = option('mysql')     || 'mysql'
    host      = option('host')      || '127.0.0.1'
    user      = option('user')      || 'root'
    password  = option('password')  || ''
    query     = option('query') || 'SELECT 0 as count;'

    query.strip!
    query.chomp!(';')

    cmd = %Q[#{mysql} --user="#{user}" --host="#{host}" --password="#{password}" --execute="#{query.gsub(/"/,'\"')}\\G"]

    result ={}
    Open3.popen3(cmd) do |stdin, stdout, stderr|
      while out = stdout.gets
        next unless out.match(/:/)
        line = out.split(/:/)
        result[line.first.strip.to_sym] = line.last.strip
      end
    end     
    result
  end

end
