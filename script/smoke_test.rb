# frozen_string_literal: true
# Smoke test for Ulog binary v0 (varint + delta-ts)
# Validates: write persists bytes; export yields 3 human-readable lines.

require "fileutils"
require "stringio"
require "tmpdir"

# Use library directly from repo (no need to install gem)
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ulog"

failures = []

Dir.mktmpdir("ulog_smoke") do |dir|
  path = File.join(dir, "app.mlog")

  log = Ulog::Store.new(path)
  log.write(code: 123, severity: :warn, channel: :sns, payload: {sensor_id: 7, ms: 850})
  log.write(code: 45,  severity: :info, channel: :net, payload: {retries: 2})
  log.write(code: 45,  severity: :info, channel: :net, payload: {retries: 3})

  # 1) file should be non-empty
  size = File.size?(path) || 0
  failures << "log file is empty" if size <= 0

  # 2) export should produce 3 lines
  out = StringIO.new
  log.export(io: out)
  lines = out.string.split("\n")
  failures << "export produced #{lines.size} lines (expected 3)" unless lines.size == 3

  # 3) each line should match the human pattern: #-<code>-<sev>-<ch>-HH:MM:SS.mmm { ... }
  re = /\A#-\d+-[a-z]+-[a-z]+-\d{2}:\d{2}:\d{2}\.\d{3}\s\{.*\}\z/
  lines.each_with_index do |ln, i|
    failures << "line #{i+1} did not match pattern: #{ln.inspect}" unless ln.match?(re)
  end

  # 4) specific checks for first and second lines (code/sev/ch known)
  failures << "first line missing code=123" unless lines[0]&.include?("#-123-")
  failures << "first line sev warn"         unless lines[0]&.include?("-warn-")
  failures << "first line ch sns"           unless lines[0]&.include?("-sns-")
  failures << "second line code=45"         unless lines[1]&.include?("#-45-")
  failures << "second line sev info"        unless lines[1]&.include?("-info-")
  failures << "second line ch net"          unless lines[1]&.include?("-net-")
end

if failures.empty?
  puts "SMOKE OK"
  exit 0
else
  warn "SMOKE FAIL:\n - " + failures.join("\n - ")
  exit 1
end