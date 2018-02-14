require_relative 'handler'
require 'maxcube/messages/parser'

module MaxCube
  module Messages
    module TCP
      class Parser
        include Handler
        include Messages::Parser

        %w[a c f h l m n s].each { |f| require_relative 'type/' << f }

        MSG_TYPES = %w[H F L C M N A E D b g j p o v w S].freeze

        include MessageA
        include MessageC
        include MessageF
        include MessageH
        include MessageL
        include MessageM
        include MessageN
        include MessageS

        # Process set of messages - raw data separated by "\r\n"
        # @param [String, #read] raw data from a Cube
        # @return [Array<Hash>] particular message contents
        def parse_tcp_data(raw_data)
          check_tcp_data(raw_data)
          raw_data.split("\r\n").map(&method(:parse_tcp_msg))
        end

        # Parse single message already without "\r\n"
        # @param [String, #read] single message data without "\r\n"
        # @return [Hash] particular message parts separated into hash,
        #                which should be human readable
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
