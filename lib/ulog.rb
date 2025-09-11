# frozen_string_literal: true
require "json"
require "time"
require "stringio"
require_relative "ulog/version"
require_relative "ulog/varint"
require_relative "ulog/crc8"


module Ulog
  class Store
    MAGIC  = "UL".b    # 0x55 0x4C
    V1     = 0x01
    DEFAULT_BLOCK_BYTES = 64 * 1024

    def initialize(path, target_bytes: 256*1024, dict: nil, block_target_bytes: DEFAULT_BLOCK_BYTES)
      @path = path
      @target_bytes = target_bytes
      @dict = dict
      @block_target_bytes = block_target_bytes
      
      File.open(@path, "ab") {}
      
      start_new_block(Time.now)
    end

    # Writes one binary record:
    # code(vu) | sev(vu) | ch(vu) | ts_ms(vu) | len(vu) | payload(bytes)
    def write(code:, severity:, channel:, payload: nil, at: Time.now)
      rotate_block_if_needed!

      delta_ms = (now_ms(at) - @t_anchor_ms)
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
      @block_bytes += rec.bytesize
    end

    # Reads the binary file and prints a human-readable line per event.
    def export(io: $stdout, min_sev: :trace, since: nil)
      min_sev_code = to_sev_code(min_sev)
      current_anchor = nil

      File.open(@path, "rb") do |f|
        buf = f.read
        return if buf.nil? || buf.empty?
        sio = StringIO.new(buf)

        until sio.eof?

           if (b1 = sio.read(1))
            if b1 == MAGIC.getbyte(0).chr
              b2 = sio.read(1)
              b3 = sio.read(1)
              if b2 == MAGIC.getbyte(1).chr && b3 && b3.ord == V1
                current_anchor = Varint.decode_u(sio)
                next
              else
                # recua se não era header
                sio.pos -= 3
              end
            else
              sio.pos -= 1
            end
          else
            break
          end

          start_pos = sio.pos

          code = Varint.decode_u(sio)
          sev  = Varint.decode_u(sio)
          ch   = Varint.decode_u(sio)
          dms  = Varint.decode_u(sio)
          len  = Varint.decode_u(sio)
          data = sio.read(len) || "".b

          # Reads recorded CRC (1 byte). if its missing, we branded it as corrupted and abort.
          crc_byte = sio.read(1)
          bad_crc = false
          if crc_byte && crc_byte.bytesize == 1
            end_pos = sio.pos
            sio.pos = start_pos
            rec_bytes = sio.read(end_pos - start_pos - 1) # everything except CRC
            sio.pos = end_pos
            expected = CRC8.calc(rec_bytes)
            actual = crc_byte.ord
            bad_crc = (expected != actual)
          else
            bad_crc = true
          end

          next if sev < min_sev_code
          anchor = current_anchor || file_birth_ms # fallback
          ts_abs = Time.at((anchor + dms) / 1000.0).utc
          human = JSON.parse(data, symbolize_names: true) rescue {}

          tag = bad_crc ? " BAD_CRC" : ""
          io.puts "#-#{code}-#{from_sev_code(sev)}-#{from_ch_code(ch)}-#{ts_abs.strftime("%H:%M:%S.%L")}#{tag} #{human.inspect}"
        end
      end
    end

    private

    def start_new_block(at_time)
      @t_anchor_ms = now_ms(at_time)
      header = +"".b
      header << MAGIC
      header << V1.chr
      header << Varint.encode_u(@t_anchor_ms)
      File.open(@path, "ab") { |f| f.write(header) }
      @block_bytes = 0
    end

    def rotate_block_if_needed!
      if @block_bytes >= @block_target_bytes
        start_new_block(Time.now)
      end
    end

    def now_ms(t = Time.now) = (t.to_f * 1000).to_i


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
