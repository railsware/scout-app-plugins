class RabbitmqOverall < Scout::Plugin
  def build_report
    report_data = {}
    report_data.merge!(get_general_stats)
    report_data.merge!(get_detailed_stats)
    
    # format memory to MB
    report_data.each_pair do |k,v|
      report_data[k]=v.to_f/(1024*1024) if k.match(/memory/)
    end
  
    report(report_data)
  rescue RuntimeError => e
    add_error(e.message)
  end

  def get_detailed_stats
    stat_params = option('queue_stat_params') && option('queue_stat_params').split(',')
    stat_params ||= []
    report_data = {}
    cmd = "#{rabbitmqctl} -q list_queues #{(['name']+stat_params).join(' ')}"

    `#{cmd}`.to_a.each do |line|
      values = line.split
      name=values.shift

      values.each_with_index do |val, index|
        report_data.merge!("#{name}_#{stat_params[index]}" => val)
      end
      
    end
    report_data
  end
  
  def get_general_stats
    report_data = {}
    report_data['queues'] = 0
    report_data['exchanges'] = 0
    report_data['bindings'] = 0


    report_data['connections'] = `#{rabbitmqctl} -q list_connections`.to_a.size

    vhosts.each do |vhost|
      cmd = "#{rabbitmqctl} -q list_queues -p '#{vhost}' messages memory"
      queue_stats = `#{cmd}`.to_a.map{|e| e.chomp}
      
      report_data['queues'] += queue_stats.size        
      message_memory_report = queue_stats.inject({'total_messages' => 0, 'total_memory' => 0}) do |total, line|
        val = line.split
        total['total_messages'] += val[0].to_i
        total['total_memory'] += val[1].to_i

        total
      end
      report_data.merge!(message_memory_report)


      report_data['exchanges'] += `#{rabbitmqctl} -q list_exchanges -p #{vhost}`.to_a.size
      report_data['bindings'] += `#{rabbitmqctl} -q list_bindings -p #{vhost}`.to_a.size
    end
    report_data
  end
  
  def rabbitmqctl
    option('rabbitmqctl') || 'rabbitmqctl'
  end

  def vhosts
    @vhosts ||= `#{rabbitmqctl} -q list_vhosts`.to_a.map{|e| e.chomp}
  end
  
  def stats_per_queue
  end

  # def `(command)
  #   result = super(command)
  #   if ($? != 0)
  #     raise "[#{command}] exited with a non-zero value: #{$?}"
  #   end
  #   result
  # end
end
