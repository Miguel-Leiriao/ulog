# frozen_string_literal: true
require "json"
require "time"
require "stringio"
require_relative "ulog/version"
require_relative "ulog/varint"
require_relative "ulog/crc8"


module Ulog
  class Store
    def initialize(path, target_bytes: 256*1024, dict: nil)
      @path = path
      @target_bytes = target_bytes
      @dict = dict
      File.open(@path, "ab") {}
      @t0 = file_birth_ms
    end

    # Writes one binary record:
    # code(vu) | sev(vu) | ch(vu) | ts_ms(vu) | len(vu) | payload(bytes)
    def write(code:, severity:, channel:, payload: nil, at: Time.now)
      ts_ms = ((at.to_f * 1000).to_i - @t0)
      sev = to_sev_code(severity)
      ch  = to_ch_code(channel)
      data = JSON.dump(payload || {})

      rec = +"".b
      rec << Varint.encode_u(code.to_i)
      rec << Varint.encode_u(sev)
      rec << Varint.encode_u(ch)
      rec << Varint.encode_u(ts_ms)
      rec << Varint.encode_u(data.bytesize)
      rec << data

      crc = CRC8.calc(rec)
      rec << crc.chr  

      File.open(@path, "ab") { |f| f.write(rec) }
    end

    # Reads the binary file and prints a human-readable line per event.
    def export(io: $stdout, min_sev: :trace, since: nil)
      min_sev_code = to_sev_code(min_sev)
      File.open(@path, "rb") do |f|
        buf = f.read
        return if buf.nil? || buf.empty?
        sio = StringIO.new(buf)
        until sio.eof?
          start_pos = sio.pos

          code = Varint.decode_u(sio)
          sev  = Varint.decode_u(sio)
          ch   = Varint.decode_u(sio)
          ts   = Varint.decode_u(sio)
          len  = Varint.decode_u(sio)
          data = sio.read(len) || "".b

          # Reads recorded CRC (1 byte). if its missing, we branded it as corrupted and abort.
          crc_byte = sio.read(1)
          bad_crc = false
          if crc_byte && crc_byte.bytesize == 1
            end_pos = sio.pos
            sio.pos = start_pos
            rec_bytes = sio.read(end_pos - start_pos - 1) # tudo menos o CRC
            sio.pos = end_pos
            expected = CRC8.calc(rec_bytes)
            actual = crc_byte.ord
            bad_crc = (expected != actual)
          else
            bad_crc = true
          end

          next if sev < min_sev_code
          ts_abs = Time.at((@t0 + ts) / 1000.0).utc
          human = JSON.parse(data, symbolize_names: true) rescue {}

          io.puts "#-#{code}-#{from_sev_code(sev)}-#{from_ch_code(ch)}-#{ts_abs.strftime("%H:%M:%S.%L")}#{tag} #{human.inspect}"
        end
      end
    end

    private

    def file_birth_ms
      st = File.stat(@path)
      ((st.ctime.to_f) * 1000).to_i
    end

    # simple map for now (0..7 for severities, 0.8 for channels)
    SEV_TO = { trace:0, debug:1, info:2, warn:3, notice:4, error:5, crit:6, alert:7 }.freeze
    CH_TO  = { net:0, io:1, auth:2, sns:3, cfg:4, pwr:5, app:6, db:7, ui:8 }.freeze
    SEV_FROM = SEV_TO.invert.freeze
    CH_FROM  = CH_TO.invert.freeze

    def to_sev_code(val)
      return val if val.is_a?(Integer)
      sym = val.is_a?(Symbol) ? val : val.to_s.downcase.to_sym
      SEV_TO.fetch(sym) { Integer(val) rescue 0 }
    end

    def to_ch_code(val)
      return val if val.is_a?(Integer)
      sym = val.is_a?(Symbol) ? val : val.to_s.downcase.to_sym
      CH_TO.fetch(sym) { Integer(val) rescue 0 }
    end

    # Accepts Integer, Symbol, or String (e.g., "warn")
    def from_sev_code(n)
      SEV_FROM[n] || n
    end

    def from_ch_code(n)
      CH_FROM[n] || n
    end
  end
end
