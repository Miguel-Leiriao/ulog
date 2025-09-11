# frozen_string_literal: true
module Ulog
  module Varint
    module_function

    # encode_u(n) -> String (binary)
    # Encodes an unsigned integer using a LEB128-like varint.
    # Emits 7 bits per byte; MSB=1 means "more bytes follow".
    # Example: 300 => [0b10101100, 0b00000010]
    def encode_u(n)
      out = +"".b  # binary string
      loop do
        byte = n & 0x7F
        n >>= 7
        byte |= 0x80 if n > 0
        out << byte
        break if n == 0
      end
      out
    end

    # decode_u(io) -> Integer
    # Reads bytes from an IO/StringIO and decodes a varint written by encode_u.
    # Raises EOFError if the stream ends unexpectedly.
    def decode_u(io)
      shift = 0
      num = 0
      loop do
        b = io.read(1)
        raise EOFError, "varint eof" unless b
        byte = b.ord
        num |= ((byte & 0x7F) << shift)
        if (byte & 0x80) == 0
          return num
        end
        shift += 7
      end
    end
  end
end