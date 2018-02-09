
module MaxCube
  class MessageParser < MessageHandler
    private

    module MessageF
    end

    # NTP server message
    def parse_f(body)
      { ntp_servers: body.split(',') }
    end
  end

  class MessageSerializer < MessageHandler
    private

    module MessageF
    end

    # Request for NTP servers message (F)
    # Optionally, updates can be done
    def serialize_f(hash)
      hash.include?(:ntp_servers) ? hash[:ntp_servers].join(',') : ''
    end
  end
end
