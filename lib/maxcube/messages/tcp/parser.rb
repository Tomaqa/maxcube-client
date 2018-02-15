require_relative 'handler'
require 'maxcube/messages/parser'

module MaxCube
  module Messages
    module TCP
      # Extends {Messages::Parser} and {TCP::Handler} of routines
      # connected to TCP Cube messages parsing.
      class Parser
        include TCP::Handler
        include Messages::Parser

        %w[a c f h l m n s].each do |f|
          require_relative 'type/' << f
          include const_get('Message' << f.upcase)
        end

        # Known message types in the direction Cube -> client.
        MSG_TYPES = %w[H F L C M N A E D b g j p o v w S].freeze

        # Processes set of messages - raw data separated by +\\r\\n+.
        # Calls {#check_tcp_data}
        # and maps {#parse_tcp_msg} on each message.
        # @param raw_data [String] raw data from a Cube
        # @return [Array<Hash>] particular message contents
        def parse_tcp_data(raw_data)
          check_tcp_data(raw_data)
          raw_data.split("\r\n").map(&method(:parse_tcp_msg))
        end

        # Parses single message already without +\\r\\n+.
        # Subsequently calls {#check_tcp_msg},
        # {#parse_msg_body}
        # and {#check_tcp_hash}.
        # @param msg [String] input message (without +\\r\\n+).
        # @return [Hash] particular message contents separated into hash.
        def parse_tcp_msg(msg)
          check_tcp_msg(msg)
          body = msg.split(':')[1] || ''
          hash = { type: @msg_type }
          return hash unless parse_msg_body(body, hash, 'tcp')
          check_tcp_hash(hash)
        end
      end
    end
  end
end
