require 'time'
require 'date'

class MissingLibrary < StandardError; end
class MysqlReplicationMonitor < Scout::Plugin

  
  attr_accessor :connection
  
  
  def setup_mysql
    begin
      require 'mysql'
    rescue LoadError
      begin
        require "rubygems"
        require 'mysql'
      rescue LoadError
        raise MissingLibrary
      end
    end
    self.connection=Mysql.new(option(:host),option(:username),option(:password))
  end
  
  def build_report
    begin
      setup_mysql
      h=connection.query("show slave status").fetch_hash
      if h.nil? 
        error("Replication not configured") 
      elsif h["Slave_IO_Running"] == "Yes" and h["Slave_SQL_Running"] == "Yes"
        report("Seconds Behind Master"=>h["Seconds_Behind_Master"])
        report("Replication Down Time"=>0)
        memory.delete(:replication_down_time) if memory(:replication_down_time).to_i > 0
      else
        tm = memory(:replication_down_time).to_i + 1
        remember(:replication_down_time => tm)
        report("Replication Down Time" => tm)
        alert("Replication not running",
          "IO Slave: #{h["Slave_IO_Running"]}\nSQL Slave: #{h["Slave_SQL_Running"]}") unless in_ignore_window?
      end
    rescue  MissingLibrary=>e
      error("Could not load all required libraries",
            "I failed to load the mysql library. Please make sure it is installed.")
    rescue Mysql::Error=>e
      error("Unable to connect to mysql: #{e}")
    rescue Exception=>e
      error("Got unexpected error: #{e} #{e.class}")
    end
  end

  def in_ignore_window?
    if s=option(:ignore_window_start) && e=option(:ignore_window_end)
      start_time = Time.parse("#{Date.today} #{s}")
      end_time = Time.parse("#{Date.today} #{e}")
      
      if start_time<end_time
        return(Time.now > start_time and Time.now < end_time)
      else
        return(Time.now > start_time or Time.now < end_time)
      end
    else
      false  
    end
  end

end