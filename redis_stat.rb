class RedisStat < Scout::Plugin
  OPTIONS=<<-EOS
  options:
    redis-cli:
      name: redis-cli command
      notes: redis-cli command
      default: /usr/local/bin/redis-cli
    general_fields:
      name: general stat fields
      notes: general stat fields
      default: used_memory, changes_since_last_save, uptime_in_days, bgsave_in_progress

  metadata:
    used_memory_in_kb:
      label: Used memory(KB)
      precision: 2
      units: KB

    used_memory_in_mb:
      label: Used memory(MB)
      precision: 2
      units: MB

  EOS

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
