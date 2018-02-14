require_relative 'udp'
require_relative '../handler'

require 'ipaddr'

module MaxCube
  module Messages
    module UDP
      module Handler
        include Messages::Handler

        def valid_udp_msg_prefix(msg)
          msg.start_with?(self.class.const_get('MSG_PREFIX'))
        end

        def check_udp_msg_prefix(msg)
          raise InvalidMessageFormat unless valid_udp_msg_prefix(msg)
        end

        def valid_udp_msg(msg)
          valid_udp_msg_prefix(msg) &&
            valid_msg(msg)
        end

        def check_udp_msg(msg)
          check_udp_msg_prefix(msg)
          check_msg(msg)
          msg
        end
      end
    end
  end
end
