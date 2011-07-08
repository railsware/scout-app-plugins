# Directory File Counter
# =================================
# Created by [Dmitry Larkin](http://github.com/dml)
# 
# Returs directory file count.
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
  options:
    directory:
      name: directory
      notes: Traget directory
      default: '/var/log'
    command:
      name: command
      notes: 'Command which used four counting. Examples: `ls -l | wc -l -2` or `find . -type f | wc -l`'
      default: 'find . -type f | wc -l'

  metadata:
    count:
      label: Count
      precision: 0

  triggers:
    - type: peak
      dname: count
      max_value: 4
  EOS

  def build_report
    report(:count => find_files.strip.to_i)
  rescue Exception => e
    error "Couldn't parse output. Make sure you have proper SQL. #{e}"
    logger.error e
  end

  private

  def find_files
    dir = option('directory') || "."
    counter = option('command') || "find . -type f | wc -l"
    command = "cd #{dir} && #{counter}"

    `#{command}`
  end
end