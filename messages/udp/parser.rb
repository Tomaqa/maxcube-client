require_relative 'handler'
require_relative '../parser'

%w[i n h].each { |f| require_relative 'type/' << f }

module MaxCube
  module Messages
    module UDP
      class Parser
        include Handler
        include Messages::Parser

        MSG_TYPES = %w[I N h c].freeze

        include MessageI
        include MessageN
        include MessageH

        MSG_PREFIX = (UDP::MSG_PREFIX + 'Ap').freeze

        def parse_udp_msg(msg)
          @io = StringIO.new(msg, 'rb')
          hash = {
            prefix: read(8),
            serial_number: read(10),
            id: read(1, true),
            type: read(1),
          }
          msg_type = hash[:type]
          method_str = "parse_udp_#{msg_type.downcase}"
          return hash.merge!(send(method_str)) if respond_to?(method_str)
          # bitka
        end
      end
    end
  end
end
