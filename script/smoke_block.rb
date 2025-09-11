# frozen_string_literal: true
require "tmpdir"
require "stringio"
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ulog"

failures = []

Dir.mktmpdir("ulog_block") do |dir|
  path = File.join(dir, "app.mlog")
  # força rotação frequente: ~128 bytes por bloco
  log = Ulog::Store.new(path, block_target_bytes: 128)

  50.times do |i|
    log.write(code: i % 5, severity: :info, channel: :app, payload: {i: i})
  end

  bytes = File.binread(path)
  # conta headers "UL\x01"
  header_pat = "UL".b + "\x01"
  header_count = bytes.scan(Regexp.new(Regexp.escape(header_pat), nil, "n")).size
  failures << "expected >= 2 block headers, got #{header_count}" unless header_count >= 2

  # export não deve rebentar
  out = StringIO.new
  log.export(io: out)
  lines = out.string.split("\n")
  failures << "expected >= 50 lines, got #{lines.size}" unless lines.size >= 50
end

if failures.empty?
  puts "BLOCKS OK"
  exit 0
else
  warn "BLOCKS FAIL:\n - " + failures.join("\n - ")
  exit 1
end
