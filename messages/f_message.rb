
module MaxCube
  # class MessageParser < MessageHandler
  class Messages
    module Parser
      module TCP
    private

    module MessageF
    end

    # NTP server message
    def parse_f(body)
      { ntp_servers: body.split(',') }
    end
  end
end

  # class MessageSerializer < MessageHandler
  module Serializer
      module TCP
    private

    module MessageF
      OPT_KEYS = %i[ntp_servers].freeze
    end

    # Request for NTP servers message (F)
    # Optionally, updates can be done
    def serialize_f(hash)
      hash.key?(:ntp_servers) ? hash[:ntp_servers].join(',') : ''
    end
  end
end
end
end
