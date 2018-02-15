require_relative 'handler'
require 'maxcube/messages/parser'

module MaxCube
  module Messages
    module UDP
      # Extends {Messages::Parser} and {UDP::Handler} of routines
      # connected to UDP Cube messages parsing.
      class Parser
        include UDP::Handler
        include Messages::Parser

        # Mandatory hash keys common for all UDP Cube messages.
        KEYS = %i[prefix serial_number id].freeze

        %w[i n h].each do |f|
          require_relative 'type/' << f
          include const_get('Message' << f.upcase)
        end

        # Known message types in the direction Cube -> client.
        MSG_TYPES = %w[I N h c].freeze

        # {UDP::MSG_PREFIX} with a suffix.
        MSG_PREFIX = (UDP::MSG_PREFIX + 'Ap').freeze

        # Parses single message.
        # Subsequently calls {#check_udp_msg},
        # {#parse_udp_msg_head}, {#parse_msg_body}
        # and {#check_udp_hash}.
        # @param msg [String] input message.
        # @return [Hash] particular message contents separated into hash.
        def parse_udp_msg(msg)
          check_udp_msg(msg)
          hash = parse_udp_msg_head(msg)
          return hash unless parse_msg_body(@io.string, hash, 'udp')
          check_udp_hash(hash)
        end

        private

        # Tells how to get message type from a message.
        # @param msg [String] input message.
        # @return [String] message type.
        def msg_msg_type(msg)
          msg[19]
        end

        # Parses head of UDP Cube message, that is common to all of these.
        # Internal +IO+ variable contains message body string at the end.
        # @param msg [String] input message.
        # @return [Hash] particular message head contents separated into hash.
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
