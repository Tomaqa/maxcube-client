require_relative 'handler'
require_relative '../parser'

module MaxCube
  module Messages
    module UDP
      class Parser
        include Handler
        include Messages::Parser

        KEYS = %i[prefix serial_number id].freeze

        %w[i n h].each { |f| require_relative 'type/' << f }

        MSG_TYPES = %w[I N h c].freeze

        include MessageI
        include MessageN
        include MessageH

        MSG_PREFIX = (UDP::MSG_PREFIX + 'Ap').freeze

        def parse_udp_msg(msg)
          check_udp_msg(msg)
          hash = parse_udp_msg_head(msg)
          return hash unless parse_msg_body(@io.string, hash, 'udp')
          check_udp_hash(hash)
        end

        private

        def msg_msg_type(msg)
          msg[19]
        end

        def parse_udp_msg_head(msg)
          @io = StringIO.new(msg, 'rb')
          hash = {
            prefix: read(8),
            serial_number: read(10),
            id: read(1, true),
            type: read(1),
          }
          @io.string = @io.read
          hash
        end
      end
    end
  end
end
