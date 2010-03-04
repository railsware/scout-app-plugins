class ScriptExecuter < Scout::Plugin

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
