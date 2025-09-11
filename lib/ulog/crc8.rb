# frozen_string_literal: true
module Ulog
  module CRC8
    module_function
    # CRC-8-ATM (polynomial 0x07), init 0x00, no xor-out
    def calc(bytes)
      crc = 0
      bytes.each_byte do |b|
        crc ^= b
        8.times do
          if (crc & 0x80) != 0
            crc = ((crc << 1) & 0xFF) ^ 0x07
          else
            crc = (crc << 1) & 0xFF
          end
        end
      end
      crc
    end
  end
end
