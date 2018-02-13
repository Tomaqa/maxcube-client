
module MaxCube
  # class MessageParser < MessageHandler
  # class Messages
  module Messages
      module TCP
    # module Parser
    class Parser
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
      module TCP
  # module Serializer
  class Serializer
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
