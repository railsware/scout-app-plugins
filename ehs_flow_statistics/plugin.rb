class EhsFlowStatistics < Scout::Plugin
  needs 'yaml'
  KILOBYTE = 1024
  MEGABYTE = 1048576

  def build_report
    cmd = "#{option('redis-cli')||'redis-cli'} info"
    result = `#{cmd}`
    redis_info = YAML.load(result.gsub(/:/, ": "))
    error(:subject => 'redis-cli error', :body => "[#{cmd}]:#{result}") unless redis_info
    data = {}
    
    data['used_memory_in_kb'] = redis_info['used_memory'].to_f / KILOBYTE
    data['used_memory_in_mb'] = redis_info['used_memory'].to_f / MEGABYTE
    data['last_save_time'] = Time.at(redis_info['last_save_time']).strftime("%Y-%m-%d %H:%M:%S")

    # General Stats

    option('general_fields') && option('general_fields').split(',').map{|f| f.strip}.each do |key|
      data[key] = redis_info[key]
    end
    report(data)
  end
end
