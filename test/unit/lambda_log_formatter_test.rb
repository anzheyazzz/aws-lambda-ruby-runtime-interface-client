# frozen_string_literal: true

require_relative '../../lib/aws_lambda_ric/lambda_log_formatter'
require 'json'
require 'logger'
require 'securerandom'
require 'time'
require 'minitest/autorun'

class LambdaLogFormatterTest < Minitest::Test
  def test_formatter
    $_global_aws_request_id = SecureRandom.uuid
    time = Time.now
    progname = 'test_progname'
    msg = 'log_message'
    under_test = LogFormatter.new

    actual = under_test.call('INFO', time, progname, msg)

    assert_equal "I, [#{time.strftime("%Y-%m-%dT%H:%M:%S.%6N")} ##{$$}]  INFO #{$_global_aws_request_id} -- #{progname}: #{msg}\n", actual
  end
end

class JsonLogFormatterTest < Minitest::Test
  def test_formats_standard_log_message
    $_global_aws_request_id = 'request-id-1'
    formatter = JsonLogFormatter.new

    output = formatter.call('INFO', Time.utc(2026, 2, 23, 16, 29, 1), 'app', 'hello')
    parsed = JSON.parse(output)

    assert_equal '2026-02-23T16:29:01.000000Z', parsed['timestamp']
    assert_equal 'INFO', parsed['level']
    assert_equal 'hello', parsed['message']
    assert_equal 'request-id-1', parsed['requestId']
    assert_equal 'app', parsed['logger']
  end

  def test_formats_exception_fields
    $_global_aws_request_id = 'request-id-2'
    formatter = JsonLogFormatter.new

    begin
      raise RuntimeError, 'something went wrong'
    rescue RuntimeError => e
      output = formatter.call('ERROR', Time.utc(2026, 2, 23, 16, 29, 1), nil, e)
      parsed = JSON.parse(output)

      assert_equal 'ERROR', parsed['level']
      assert_equal 'something went wrong', parsed['message']
      assert_equal 'RuntimeError', parsed['errorType']
      assert_equal 'something went wrong', parsed['errorMessage']
      assert_kind_of Array, parsed['stackTrace']
      refute_empty parsed['stackTrace']
      assert_match(/.+:.+:\d+/, parsed['location'])
      refute parsed.key?('logger')
    end
  end

  def test_coerces_non_string_progname
    $_global_aws_request_id = 'request-id-3'
    formatter = JsonLogFormatter.new

    output = formatter.call('INFO', Time.utc(2026, 2, 23, 16, 29, 1), 123, 'hello')
    parsed = JSON.parse(output)

    assert_equal '123', parsed['logger']
  end
end
