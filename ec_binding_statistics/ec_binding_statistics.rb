class EcBindingStatistics < Scout::Plugin
  needs 'open3','hpricot'
  KEY = 'Received Messages'.freeze
  
  def build_report      
    output = ec_console_output
    report(output[:fields])
    error(:subject => output[:errors].join(', ')) unless ( output[:errors].nil? || output[:errors].empty? )
  rescue Exception => e
    error "Couldn't parse output. #{e}"
  end

  private
  
  def cmd(options)
   %Q[#{options[:ec_console]} #{options[:user]}:#{options[:password]}@#{options[:hostname]}:#{options[:port]} #{options[:cluster_command]} #{options[:command]}]
  end
  
  def parse_record(record)
    stat= {}
    @key = ""
    record.inner_text.split("\n").each do |line|
      next if line.empty?
      key,value  = line.split(':',2)
      if value
        stat[@key][key.strip] = value.to_f
      else
        # get only binding name
        @key = key.gsub('Summary Statistics For Binding','').strip
        stat[@key] ||= {} if !@key.empty?
      end  
    end
    {record.attributes['sender'] =>  stat}
  end
  
  def ec_console_output
    options = {
      :ec_console     => option('ec_console')     || 'ec_console',
      :hostname       => option('host')           || '127.0.0.1',
      :port           => option('port')           || '2025',
      :user           => option('user')           || 'admin',
      :password       => option('password')       || '',
      :command        => option('command')        || 'binding summary'
    }
    
    result ={:fields => {}, :errors => []}
    
    Open3.popen3(cmd(options.merge(:cluster_command => 'broadcast'))) do |stdin, stdout, stderr|
      error = stderr.gets
      result[:errors]<<error.chomp! if error      
    end
    
    sleep(3)
    
   Open3.popen3(cmd(options.merge(:cluster_command => 'retrieve'))) do |stdin, stdout, stderr|
     out = stdout.read
      if ( out.nil? || out.empty? )
        result[:errors]<<"Cant retrieve output"
        break  
      end
      statistics = {}
      doc = Hpricot(out) 
      (doc/:record).each do |record|
        statistics.merge!(parse_record(record))
      end
            
      result[:fields].merge! mta_distribution(statistics)
      result[:fields].merge! group_report(statistics,/vb/)
      result[:fields].merge! group_report(statistics,/vnb/)
      result[:fields].merge! group_report(statistics,/vcb/)
      
      error = stderr.gets
      error.chomp! if error
    end
    result
   end

   # calculate sent count per mta and total for all mtas
   def mta_distribution(statistics)
     key = KEY
     distribution = {}
     # sum count across all vip's
     statistics.keys.each do |sender|
       distribution[sender] = statistics[sender].values.inject(0){|total,vip| total + vip[key]}
     end
     # count percentage
     total = distribution.values.inject(0){|total,count| total + count}
     statistics.each_key do |mta|
      distribution["#{mta}_perc"] = distribution[mta].to_f*100/total
     end
     distribution['total'] = total
     distribution
   end
   
   # calculate statistics across all mtas for vips
   # vb*
   # vnb*
   # vcb*
   def group_report(statistics, group_pattern = nil)
     key = KEY    
     aggregated_stat = sum(statistics.values, key,group_pattern)
     total = aggregated_stat.values.inject(0){|r,v| r+v}
     aggregated_stat.merge! aggregated_stat.inject({}){|memo,record| memo["#{record.to_a[0]}_deviation_in_perc"] = (record.to_a[1]*100/total - 100.0/aggregated_stat.keys.size ).abs;memo}

     aggregated_stat["#{group_pattern.source}_relative_std"] = relative_std(aggregated_stat.values) if group_pattern
     aggregated_stat["#{group_pattern.source}_total"] = total

     aggregated_stat
   end
   
   # sum n hashes
   def sum(hashes,key,pattern = nil)
     new_hash = {}
     hashes.first.keys.each do |k|
       new_hash[k] =  hashes.inject(0){|result, element| result + element[k][key] } if pattern.nil? || (!pattern.nil? && k.match(pattern))
     end
     new_hash
   end
   #std calculation
   def relative_std(values)
     total = values.inject(0){|r,v| r+v}
     average = total.to_f/values.size
     Math.sqrt(values.map{|e| (average-e)**2}.inject(0){|r,v| r+v}.to_f/values.size).to_f*100/total
   end   
   
end
