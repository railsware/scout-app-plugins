class FileCounter < Scout::Plugin
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