# Log Watcher Plugin
# =================================
# Created by [Yaroslav Lazor](http://github.com/yaroslavlazor)
# 
# Tail the difference(from the last run) of the log file and execute it through:
# - a pipe - to get a single value
# - and error pipe - to get a error body for the alert message
# 
# Simple scenario:
#  just write a "grep 'error' | wc -l" pipe, which will report amount of errors
# 
# Complex Example scenario:
#  you have a file /var/log/some.log
# 
#  a service write the follogin data into it
#    2009-10-29 15:49:35 SendEmail qid=77 thread: 3 completed: 4 of 4 time: 759
# 
#  or a following error message :
#    2009-10-29 16:13:37 SendEmail qid=77 thread=7 org.apache.commons.mail.EmailException: Sending the email to the following server failed : xx.xx.xx.xx:25
#  
#  You can create two pipes. 
#  Value pipe that will count the difference between completed: x of y 
#    egrep -o "completed: [0-9]+ of [0-9]+" | awk '{split($0,vars," ");sum=sum+vars[4]-vars[2]}END{print sum}'
#  Output : number of non-completed items
# 
#  Error pipe that will grep for "org.apache.commons.mail.EmailException" and show a uniq amount of errors
#    grep "org.apache.commons.mail.EmailException:" | awk '{gsub(/^....-..-.. ..:..:../,"date");gsub(/thread=[0-9]+/,"thread=x");print $0}' | sort | uniq -c | sort -nr 
#  Output : concatenated errors in unified format, date and thread number less
#    20 date SendEmail qid=5659170 thread=x org.apache.commons.mail.EmailException: Sending the email to the following server failed : xx.xx.xx.xx:25
#    20 date SendEmail qid=5659164 thread=x org.apache.commons.mail.EmailException: Sending the email to the following server failed : xx.xx.xx.xx:25
#    20 date SendEmail qid=5659158 thread=x org.apache.commons.mail.EmailException: Sending the email to the following server failed : xx.xx.xx.xx:25
#    20 date SendEmail qid=5659156 thread=x org.apache.commons.mail.EmailException: Sending the email to the following server failed : xx.xx.xx.xx:25
#    20 date SendEmail qid=5659154 thread=x org.apache.commons.mail.EmailException: Sending the email to the following server failed : xx.xx.xx.xx:25
#    20 date SendEmail qid=5659152 thread=x org.apache.commons.mail.EmailException: Sending the email to the following server failed : xx.xx.xx.xx:25
#    20 date SendEmail qid=5659148 thread=x org.apache.commons.mail.EmailException: Sending the email to the following server failed : xx.xx.xx.xx:25
#    19 date SendEmail qid=5659168 thread=x org.apache.commons.mail.EmailException: Sending the email to the following server failed : xx.xx.xx.xx:25
#    19 date SendEmail qid=5659162 thread=x org.apache.commons.mail.EmailException: Sending the email to the following server failed : xx.xx.xx.xx:25
#    19 date SendEmail qid=5659160 thread=x org.apache.commons.mail.EmailException: Sending the email to the following server failed : xx.xx.xx.xx:25
#     1 date SendEmail qid=5659150 thread=x org.apache.commons.mail.EmailException: Sending the email to the following server failed : xx.xx.xx.xx:25
#    
# Dependencies
# ------------
# Requires gems : [set, mysql]
# 
# Compatibility 
# -------------


class LogWatcher < Scout::Plugin
  OPTIONS=<<-EOS
  options:
    log_path:
      default: /var/log/my.log
      name: Log path
      notes: Full path to the the log file
    service_name:
      default: MyService
      name: Service name
      notes: Name of the service - the owner of the log. Will be shown in the alert
    value_pipe:
      default: egrep "PottencialError" | egrep -v "Junk" | wc -l
      name: Value Pipe
      notes: A pipe command that goes right aftail tail #{log}
    error_pipe:
      default: egrep "PottencialError" | egrep -v "Junk" | sort | uniq -c | sort -nr
      name: Error Pipe
      notes: A pipe command that goes right aftail tail #{log} to aggregate the errors and send a notification over scout

  metadata:
    value:
      unit: /min
      precision: 2

  EOS

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
      value  = `tail -c +#{last_run} #{@log_file_path} | head -c #{read_length} | #{@value_pipe}`.strip
      errors = `tail -c +#{last_run} #{@log_file_path} | head -c #{read_length} | #{@error_pipe}`.strip unless @error_pipe.empty?

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
