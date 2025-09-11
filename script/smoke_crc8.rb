# frozen_string_literal: true
require "tmpdir"
require "stringio"
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ulog"

failures = []

Dir.mktmpdir("ulog_crc8") do |dir|
  path = File.join(dir, "app.mlog")
  log  = Ulog::Store.new(path)
  log.write(code: 1, severity: :info, channel: :app, payload: {ok: true})
  log.write(code: 2, severity: :warn, channel: :net, payload: {n: 1})

  # corrompe 1 byte no meio do ficheiro
  bytes = File.binread(path).dup
  mid   = [bytes.bytesize / 2, 1].max - 1
  bytes.setbyte(mid, (bytes.getbyte(mid) ^ 0xFF))
  File.binwrite(path, bytes)

  out = StringIO.new
  log.export(io: out)
  lines = out.string.split("\n")
  failures << "expected 2 lines" unless lines.size == 2
  failures << "missing BAD_CRC mark" unless lines.any? { |l| l.include?("BAD_CRC") }
end

if failures.empty?
  puts "CRC8 OK"
  exit 0
else
  warn "CRC8 FAIL:\n - " + failures.join("\n - ")
  exit 1
end
