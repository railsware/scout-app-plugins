class SpamScoreReport < Scout::Plugin
  needs 'spam_score_client', 'benchmark'
  def build_report
    message = 'test'
    SpamScore.instance_variable_set(:@configuration, {
      'webservice' => option(:webservice)||'127.0.0.1:80',
      'service' => option(:service)||'http://127.0.0.1:80',
      'timeout' =>  60
    })
    
    cmae_time = Benchmark.realtime{ @cmae_result = SpamScore.check_message(message,'cmae') }
    sa_time = Benchmark.realtime{ @sa_result = SpamScore.check_message(message,'sa') }

    error(:subject => 'SpamAssasin error') unless @sa_result['errors'].nil?
    error(:subject => 'CloudMark error') unless @cmae_result['errors'].nil?    
    report(:cmae_execution_time => cmae_time, :spam_assasin_execution_time => sa_time)
  end

end