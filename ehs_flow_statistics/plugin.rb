class EhsFlowStatistics < Scout::Plugin
  needs 'redis', 'rp-stats'

  MEGABYTE = 1048576

  def build_report
    RpStats.load({ :hosts => option("redis") })

    stats = RpStats.flush(option("namespace"))
    stats["io"] = stats["io"].to_f / MEGABYTE

    report(stats)
  end
end
