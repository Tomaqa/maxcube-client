require_relative 'handler'
require 'maxcube/messages/serializer'

module MaxCube
  module Messages
    module UDP
      class Serializer
        include Handler
        include Messages::Serializer

        MSG_TYPES = %w[I N h c R].freeze

        MSG_PREFIX = (UDP::MSG_PREFIX + "*\x00").freeze

        def serialize_udp_hash(hash)
          check_udp_hash(hash)
          serial_number = hash[:serial_number] || '*' * 10
          msg = MSG_PREFIX + serial_number << @msg_type
          check_udp_msg(msg)
        end

        private

        def msg_msg_type(msg)
          msg[18]
        end
      end
    end
  end
end
