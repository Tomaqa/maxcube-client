
module MaxCube
  # class MessageParser < MessageHandler
  class Messages
    module Parser
      module TCP
    private

    module MessageN
    end

    # New device (pairing) message
    def parse_n(body)
      @io = StringIO.new(decode(body), 'rb')

      {
        device_type: device_type(read(1, true)),
        rf_address: read(3, true),
        serial_number: read(10),
        unknown: read(1),
      }
    rescue IOError
      raise InvalidMessageBody
        .new(@msg_type, 'unexpected EOF reached')
    end
  end
end

  # class MessageSerializer < MessageHandler
  module Serializer
      module TCP
    private

    module MessageN
      OPT_KEYS = %i[timeout].freeze
    end

    # Command to set the Cube into pairing mode
    # with optional +timeout+ in seconds
    def serialize_n(hash)
      return '' unless hash.key?(:timeout)
      format('%04x', to_int(0, 'timeout', hash[:timeout]))
    end
  end
end
end
end
