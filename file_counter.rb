# Directory File Counter
# =================================
# Returns directory file count
# Alerts if there are too many files in directory
#
# Dependencies
# ------------
# Requires the find command
#
# Compatibility 
# -------------
#
# Linux, MacOSX

class FileCounter < Scout::Plugin
  OPTIONS=<<-EOS
  directory:
    name: "directory"
    notes: "Traget directory"
    default: "/var/log"
  command:
    name: "command"
    notes: 'Command which used four counting. Examples: `ls -l | wc -l -2` or `find . -type f | wc -l`'
    default: 'find . -type f | wc -l'
  threshold:
    name: "Threshold"
    notes: "Threshold of allowed files number per directory, use 0 for unlimited"
    default: 0
  EOS

  def build_report
    threshold = option(:threshold).to_i
    begin
      files_count = find_files.strip.to_i
    rescue Exception => e
      logger.error e
      error("Could not get number of files in #{option(:directory)} directory") and return
    end      
    
    if (threshold !=0) && (files_count >= option(:threshold))
      alert("#{option(:directory)} files count (#{files_count}) exceeded allowable threshold (#{threshold})")
    end
  
    report(:count => files_count)
  end

  private

  def find_files
    dir = option('directory') || "."
    counter = option('command') || "find . -type f | wc -l"
    command = "cd #{dir} && #{counter}"

    `#{command}`
  end
end