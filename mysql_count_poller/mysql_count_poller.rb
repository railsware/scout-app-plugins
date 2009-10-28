class MysqlCountPoller < Scout::Plugin
  def build_report
    string = query_output_string.split(/:/).last
    string.strip!

    report(:count => string)
  rescue Exception => e
    error "Couldn't parse output. Make sure you have proper SQL. #{e}"
    logger.error e
  end

  private

  def query_output_string
    mysql     = option('mysql') || 'mysql'
    host      = option('host') || '127.0.0.1'
    user      = option('user') || 'root'
    password  = option('password') || ''
    query     = option('query') || 'SELECT 0;'

    query.strip!
    query.chomp!(';')

    cmd = "#{mysql} --user='#{user}' --host='#{host}' --password='#{password}' --execute='#{query}\\G' | tail -n1"

    `#{cmd}`
  end

end
