
module MaxCube
  class MessageReceiver < MessageHandler
    private

    module MessageN
    end

    # New device (pairing) message
    def parse_n(body)
      @io = StringIO.new(decode(body), 'rb')

      {
        device_type: check_device_type(read(1, 'C')),
        rf_address: read(3),
        serial_number: read(10),
        unknown: read(1),
      }
    rescue IOError
      raise InvalidMessageBody
        .new(@msg_type, 'unexpected EOF reached')
    end
  end
end
