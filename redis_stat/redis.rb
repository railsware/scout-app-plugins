class Redis < Scout::Plugin
  needs 'yaml'
  needs 'rp-stat'

  KILOBYTE = 1024
  MEGABYTE = 1048576

  def build_report
    report(data)
  end
end
