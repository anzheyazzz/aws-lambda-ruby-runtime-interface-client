# frozen_string_literal: true

require 'json'
require 'logger'

class LogFormatter < Logger::Formatter
  FORMAT = '%<sev>s, [%<datetime>s #%<process>d] %<severity>5s %<request_id>s -- %<progname>s: %<msg>s'

  def call(severity, time, progname, msg)
    formatted = FORMAT % {
      sev: severity[0..0],
      datetime: format_datetime(time),
      process: $$,
      severity: severity,
      request_id: $_global_aws_request_id,
      progname: progname,
      msg: msg2str(msg)
    }
    "#{formatted.encode('UTF-8', invalid: :replace, undef: :replace, replace: '�')}\n"
  end
end

class JsonLogFormatter < Logger::Formatter
  DATETIME_FORMAT = '%Y-%m-%dT%H:%M:%S.%6NZ'

  def call(severity, time, progname, msg)
    payload = {
      timestamp: time.utc.strftime(DATETIME_FORMAT),
      level: severity,
      message: message_for(msg),
      requestId: $_global_aws_request_id
    }

    logger_name = progname.to_s
    payload[:logger] = logger_name unless logger_name.empty?

    if msg.is_a?(Exception)
      payload[:errorType] = msg.class.to_s
      payload[:errorMessage] = msg.message
      payload[:stackTrace] = msg.backtrace || []
      location = location_for(msg)
      payload[:location] = location unless location.nil?
    end

    "#{JSON.generate(payload.compact)}\n"
  end

  private

  def message_for(msg)
    return msg.message if msg.is_a?(Exception)

    msg2str(msg)
  end

  def location_for(exception)
    first_backtrace_line = exception.backtrace&.first
    return nil if first_backtrace_line.nil?

    matched = first_backtrace_line.match(/\A(.+):(\d+):in [`'](.+)'\z/)
    return "#{matched[1]}:#{matched[3]}:#{matched[2]}" if matched

    first_backtrace_line
  end
end
