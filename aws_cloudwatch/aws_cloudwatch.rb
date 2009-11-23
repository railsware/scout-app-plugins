class AwsCloudwatch < Scout::Plugin
  TIME_FORMAT='%Y-%m-%dT%H:%M:%S+00:00' unless const_defined?('TIME_FORMAT')

  def build_report
    aws_access_key = option(:aws_access_key)
    aws_secret = option(:aws_secret)
    dimension = option(:dimension)
    namespace = option(:namespace)

    # Available measures for EC2 instances:
    # NetworkIn NetworkOut DiskReadOps DiskWriteOps DiskReadBytes DiskWriteBytes CPUUtilization
    ec2_measures=%w(NetworkIn NetworkOut DiskReadOps DiskWriteOps DiskReadBytes DiskWriteBytes CPUUtilization)
    
    # Available measures for RDS instances:
    # CPUUtilization DatabaseConnections FreeStorageSpace
    rds_measures=%w(CPUUtilization DatabaseConnections FreeStorageSpace)
    namespaces = ['AWS/EC2', 'AWS/RDS']
    
    unless namespaces.include? namespace
      error(:subject=>'Cloudwatch namespace not set', :body=>'Ensure your namespace is set in plugin options')
      return
    end
    
    measures = case namespace
    when 'AWS/EC2' 
      then ec2_measures
    when 'AWS/RDS' 
      then rds_measures
    end

    # validate access keys
    if aws_access_key.to_s == '' or aws_secret.to_s == ''
      error(:subject=>'Cloudwatch AWS access not set', :body=>'Ensure your AWS access info is set in plugin options')
      return
    end

    # validate dimension option
    if dimension.to_s == ''
      error(:subject=>'Cloudwatch options not set properly', :body=>'You need a value for InstanceID (dimension)')
      return
    elsif dimension.include? '='
      dimension_name, dimension_value=dimension.split('=',2)
    else
      dimension_name = case namespace
      when 'AWS/EC2' 
        then 'InstanceId'
      when 'AWS/RDS' 
        then 'DBInstanceIdentifier'
      end
      dimension_value=dimension
    end

    aws = CloudWatch::AWSAuthConnection.new(aws_access_key, aws_secret)

    # Figure out a start and end time for the stats query. If we ran previously and remember the last_run_time,
    # then we just query from then to now. We also set the period to the DIFFERENCE so we only get one report during
    # that timeframe. Well, technically we make the period the closest multiple of 60 smaller than the difference,
    # because AWS needs the period to be a multiple of 60.
    #
    # If we can't remember the last_run_time, just use 300 seconds (five minutes)
    #
    # Note: Period must be multiple of 60. AWS will group the response into (end_time - start_time)/period groups.
    # Meaning, response.structure[2] (an array) will have more elements if you make period smaller. We're always
    # making the period the same as the query duration, so we always get only one group back.
    time = Time.now.utc

    if memory(:last_run_time)
      start_time = Time.parse(memory(:last_run_time))
      sample_period = ((time-start_time).to_i / 60)*60 # a multiple of 60. Will be 0 if less than 60
    end

    if memory(:last_run_time).nil? || sample_period <= 0
      sample_period = 300 # in seconds
      start_time = time - sample_period
    end
    remember(:last_run_time, time.to_s)

    # There will be one web service call for each measure
    measures.each do |measure|
      params = {
        :StartTime => start_time.strftime(TIME_FORMAT),
        :EndTime => time.strftime(TIME_FORMAT),
        :MeasureName => measure,
        :Period => sample_period.to_s,
        :Namespace => namespace,
        "Statistics.member.1" => "Average",
        "Statistics.member.2" => "Maximum",
        #"Statistics.member.3" => "Minimum",
        #"Statistics.member.4" => "Sum",
        "Dimensions.member.1.Name" => dimension_name,
        "Dimensions.member.1.Value" => dimension_value
      }

      # logger.debug ("getMetricStatistics with parameters: #{params.inspect}")
      response = aws.getMetricStatistics(params)
      # logger.debug response.structure      
      # response looks like:
      # ["CPUUtilization", [{:average=>"1.43", :timestamp=>"2009-08-16T06:40:00Z", :unit=>"Percent", :maximum=>"3.57", :samples=>"5.0"}]]
      if response.is_error?
        error(:subject=>"AWS getMetricStatistic error", :body=>response.inspect )
        return
      end
      label, stats = response.structure

      if !stats.is_a?(Array) || stats.empty?
        error(:subject=>"Something went wrong with AWS getMetricStatistics", :body=>response.inspect )
      end

      report(label+" max"=>stats.first[:maximum], label+" avg"=>stats.first[:average])

    end
  end
end


# =======================================================================
# Below here is EC2 web service library code
# =======================================================================

# -----------------------------------------------------------------------

#
# NOTE: This is based on the Amazon Web Services EC2 Query API Ruby
# Library This library has been packaged as a Ruby Gem by Glenn Rempe
# ( glenn @nospam@ elasticworkbench.com ).
#
# Source code and gem hosted on RubyForge
# under the Ruby License as of 12/14/2006:
# http://amazon-ec2.rubyforge.org

# Original Amazon Web Services Notice
# This software code is made available "AS IS" without warranties of any
# kind.  You may copy, display, modify and redistribute the software
# code either by itself or as incorporated into your code; provided that
# you do not remove any proprietary notices.  Your use of this software
# code is at your own risk and you waive any claim against Amazon Web
# Services LLC or its affiliates with respect to your use of this software
# code. (c) 2006 Amazon Web Services LLC or its affiliates.  All rights
# reserved.

require 'base64'
require 'cgi'
require 'openssl'
require 'digest/sha1'
require 'net/https'
require 'rexml/document'
require 'time'

module CloudWatch

  # Which host FQDN will we connect to for all API calls to AWS?
  DEFAULT_HOST = 'monitoring.amazonaws.com'

  # Define the ports to use for SSL(true) or Non-SSL(false) connections.
  PORTS_BY_SECURITY = { true => 443, false => 80 }

  # This is the version of the API as defined by Amazon Web Services
  API_VERSION = '2009-05-15'

  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 0
    TINY  = 1

    STRING = [MAJOR, MINOR, TINY].join('.')
  end

  # This release version is passed in with each request as part of the
  # HTTP 'User-Agent' header.  Set this be the same value as what is
  # stored in the lib/CloudWatch/version.rb module constant instead.
  # This way we keep it nice and DRY and only have to define the
  # version number in a single place.
  RELEASE_VERSION = CloudWatch::VERSION::STRING

  ###########################################################################
  #
  # Builds the canonical string for signing. This strips out all '&',
  # '?', and '=' from the query string to be signed.
  #
  # NOTE: The parameters in the path passed in must already be sorted in
  #       case-insensitive alphabetical order and must not be url encoded.
  #
  def CloudWatch.canonical_string(path)
    buf = ""
    path.split('&').each { |field|
      buf << field.gsub(/\&|\?/,"").sub(/=/,"")
    }
    return buf
  end

  ###########################################################################
  #
  # Encodes the given string with the aws_secret_access_key, by taking the
  # hmac-sha1 sum, and then base64 encoding it.  Optionally, it will also
  # url encode the result of that to protect the string if it's going to
  # be used as a query string parameter.
  #
  def CloudWatch.encode(aws_secret_access_key, str, urlencode=true)
    digest = OpenSSL::Digest::Digest.new('sha1')
    b64_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest,
                                                    aws_secret_access_key,
                                                    str)).strip
    if urlencode
      return CGI::escape(b64_hmac)
    else
      return b64_hmac
    end
  end

  ###########################################################################
  ###########################################################################
  #
  class Response
    attr_reader :http_response
    attr_reader :http_xml
    attr_reader :structure

    ERROR_XPATH = "ErrorResponse/Error"

    ######################################################################
    #
    def initialize(http_response)
      @http_response = http_response
      @http_xml = http_response.body
      @is_error = false
      if http_response.is_a? Net::HTTPSuccess
        @structure = parse
      else
        @is_error = true
        @structure = parse_error
      end
    end

    ######################################################################
    #
    def is_error?
      @is_error
    end

    ######################################################################
    #
    def parse_error
      doc = REXML::Document.new(@http_xml)
      element = REXML::XPath.first(doc, ERROR_XPATH)

      errorCode = REXML::XPath.first(element, "Code").text
      errorMessage = REXML::XPath.first(element, "Message").text

      [["#{errorCode}: #{errorMessage}"]]
    end

    ######################################################################
    #
    def parse
      # Placeholder -- this method should be overridden in child classes.
      nil
    end

    ######################################################################
    #
    def to_s
      res = ""
      @structure.each do |line|
        line.each do |k,v|
          res << "#{k}: #{v}\t"
        end
        res << "\n"
      end
      return res
    end
  end

  ######################################################################
  ######################################################################
  #
  class GetMetricStatisticsResponse < Response
    ELEMENT_XPATH = "GetMetricStatisticsResponse/GetMetricStatisticsResult/Datapoints/member"
    LABEL_XPATH = "GetMetricStatisticsResponse/GetMetricStatisticsResult/Label"

    ######################################################################
    #
    def parse
      doc = REXML::Document.new(@http_xml)
      label = REXML::XPath.first(doc, LABEL_XPATH).text
      lines = []

      doc.elements.each(ELEMENT_XPATH) do |datapoint|
        data = { }
        datapoint.each do |element|
          next if element.class == REXML::Text
          data[element.name.downcase.to_sym] = element.text
        end
        lines << data
      end
      return [label, lines]
    end
  end

  ######################################################################
  ######################################################################
  #
  class ListMetricsResponse < Response
    ELEMENT_XPATH = "ListMetricsResponse/ListMetricsResult/Metrics/member"

    ######################################################################
    #
    def parse
      doc = REXML::Document.new(@http_xml)
      lines = []

      doc.elements.each(ELEMENT_XPATH) do |element|
        measure_name = REXML::XPath.first(element, 'MeasureName').text
        namespace = REXML::XPath.first(element, 'Namespace').text

        ds = []
        REXML::XPath.each(element, "Dimensions/member") do |member|
            dim_name = REXML::XPath.first(member, 'Name').text
            dim_value = REXML::XPath.first(member, 'Value').text
            ds << [dim_name, dim_value]
        end

        lines << { :measure_name => measure_name,
          :namespace => namespace,
          :dimensions => ds,
        }
      end
      return lines
    end
  end

  ###########################################################################
  ###########################################################################
  #
  # The library exposes one main interface class, 'AWSAuthConnection'.
  # This class performs all the operations for using the CloudWatch service
  # including header signing.  This class uses Net::HTTP to interface
  # with CloudWatch Query API interface.
  class AWSAuthConnection

    # Allow viewing, or turning on and off, the verbose mode of the
    # connection class.  If 'true' some 'puts' are done to view variable
    # contents.
    #
    attr_accessor :verbose

    ########################################################################
    #
    def initialize(aws_access_key_id, aws_secret_access_key, is_secure=true,
                   server=DEFAULT_HOST, port=PORTS_BY_SECURITY[is_secure])

      @aws_access_key_id = aws_access_key_id
      @aws_secret_access_key = aws_secret_access_key
      @http = Net::HTTP.new(server, port)
      @http.use_ssl = is_secure
      # Don't verify the SSL certificates.  Avoids SSL Cert warning on every
      # GET.
      #
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      @verbose = false
    end

    ########################################################################
    #
    def getMetricStatistics(kwargs)

      # Stringify the input argument keys.
      #
      args = { }
      kwargs.each do |k,v|
        args[k.to_s] = v
      end

      GetMetricStatisticsResponse.new(make_request("GetMetricStatistics", args))
    end

    ########################################################################
    #
    def listMetrics()
      ListMetricsResponse.new(make_request("ListMetrics", { }))
    end

    private

    ########################################################################
    #
    # pathlist is a utility method which takes a key string and and array
    # as input.  It converts the array into a Hash with the hash key being
    # 'Key.n' where 'n' increments by 1 for each iteration.  So if you pass
    # in args ("ImageId", ["123", "456"]) you should get
    # {"ImageId.1"=>"123", "ImageId.2"=>"456"} returned.
    def pathlist(key, arr)
      params = {}
      arr.each_with_index do |value, i|
        params["#{key}.#{i+1}"] = value
      end
      params
    end

    ########################################################################
    #
    # Make the connection to AWS CloudWatch passing in our request.  This is
    # generally called from within a 'Response' class object or one of its
    # sub-classes so the response is interpreted in its proper context.  See
    # lib/CloudWatch/responses.rb
    #
    def make_request(action, params, data='')

      @http.start do

        params.merge!({ "Action"=>action,
                        "SignatureVersion"=>"1",
                        "AWSAccessKeyId"=>@aws_access_key_id,
                        "Version"=>API_VERSION,
                        "Timestamp"=>Time.now.getutc.iso8601})
        p(params) if @verbose

        sigpath = "?" + params.sort_by { |param| param[0].downcase }.collect { |param| param.join("=") }.join("&")

        sig = get_aws_auth_param(sigpath, @aws_secret_access_key)

        path = "?" + params.sort.collect do |param|
          CGI::escape(param[0]) + "=" + CGI::escape(param[1])
        end.join("&") + "&Signature=" + sig

        puts path if @verbose

        req = Net::HTTP::Get.new("/#{path}")

        # Ruby will automatically add a random content-type on some verbs, so
        # here we add a dummy one to 'supress' it.  Change this logic if
        # having an empty content-type header becomes semantically meaningful
        # for any other verb.
        #
        req['Content-Type'] ||= ''
        req['User-Agent'] = "ruby-cloudwatch-query-api v-#{RELEASE_VERSION}"

        data = nil unless req.request_body_permitted?
        @http.request(req, data)

      end
    end

    ########################################################################
    #
    # Set the Authorization header using AWS signed header authentication
    def get_aws_auth_param(path, aws_secret_access_key)
      canonical_string =  CloudWatch.canonical_string(path)
      encoded_canonical = CloudWatch.encode(aws_secret_access_key, canonical_string)
    end
  end
end
