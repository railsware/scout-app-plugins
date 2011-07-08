# ScriptExecuter 
# -----------------------------------------------------
# If you want to run some small Shell or Ruby script on server and get some metrics as result - ScriptExecuter is what you need!
# PROFIT: You shouldn't create each time new plugin to get needed metrics. 
# 
# Options: 
# -----------------------------------------------------
# script_lang:
#   default: shell
#   name: Script Language 
#   notes: Supported languages shell and ruby
# 
# exec_script:
#   default: ps aux | grep httpd | wc -l
#   name: Script for execution
#   notes: This script will be executed on the server
# 
# value_name:
#   default: value
#   name: Value Name
#   notes: Name for aggregatable values


class ScriptExecuter < Scout::Plugin
  OPTIONS=<<-EOS
  options:
    service_name:
      default: ScriptInjection
      name: Service name
      notes: Service name
    script_lang:
      default: shell
      name: Script Language 
      notes: Supported languages shell and ruby
    exec_script:
      default: ps aux | grep httpd | wc -l
      name: Script for execution
      notes: This script will be executed on the server
    value_name:
      default: value
      name: Value Name
      notes: Name for aggregatable values

  metadata:
    value:
      unit: /min
      precision: 2
  EOS

def build_report
  value = 0
  
  script_lang = option("script_lang").downcase
  exec_script = option("exec_script")
  value_sym = option("value_name").to_sym  
  
  if script_lang == "shell"
    value = `#{exec_script}`.strip
  elsif script_lang == "ruby"
    value = eval(exec_script).strip
  else
    error( :subject => "#{script_lang} is not supported", :body => "#{script_lang} is not supported. Supported languages are shell or ruby")
    return 
  end
  
  report(value_sym => value)
  
  rescue Exception => e
     error( :subject => "Exception appeared", :body => "#{ e } (#{ e.class })!")  
end

end
