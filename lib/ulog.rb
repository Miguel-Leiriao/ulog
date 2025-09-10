require "json"
require "time"
require_relative "ulog/version"

module Ulog
  class Store
    def initialize(path, target_bytes: 256*1024, dict: nil)
      @path = path
      File.write(@path, "") unless File.exist?(@path)
    end

    def write(code:, severity:, channel:, payload: nil, at: Time.now)
      evt = { ts: at.utc.iso8601(3), code: code.to_i, sev: severity.to_s, ch: channel.to_s, payload: payload }
      File.open(@path, "a") { |f| f.puts(evt.to_json) }
    end

    def export(io: $stdout, min_sev: :trace, since: nil)
      since_ts = since&.utc
      File.foreach(@path) do |line|
        evt = JSON.parse(line, symbolize_names: true)
        next if since_ts && Time.parse(evt[:ts]) < since_ts
        io.puts "#-#{evt[:code]}-#{evt[:sev]}-#{evt[:ch]}-#{evt[:ts]} #{evt[:payload].inspect if evt[:payload]}"
      end
    end
  end
end
