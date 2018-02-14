require_relative 'handler'
require_relative '../parser'

%w[a c f h l m n s].each { |f| require_relative 'type/' << f }

module MaxCube
  module Messages
    module TCP
      class Parser
        include Handler
        include Messages::Parser

        MSG_TYPES = %w[H F L C M N A E D b g j p o v w S].freeze

        include MessageA
        include MessageC
        include MessageF
        include MessageH
        include MessageL
        include MessageM
        include MessageN
        include MessageS

        def valid_tcp_parse_msg_type(msg)
          msg_type = msg.chr
          return msg_type if MSG_TYPES.include?(msg_type)
          false
        end

        def check_tcp_parse_msg_type(msg)
          @msg_type = valid_tcp_parse_msg_type(msg)
          return if @msg_type
          raise InvalidMessageType.new(msg.chr)
        end

        # Check single message validity, which is already without "\r\n"
        def valid_tcp_parse_msg(msg)
          valid_tcp_msg(msg) && valid_tcp_parse_msg_type(msg)
        end

        def check_tcp_parse_msg(msg)
          check_tcp_msg(msg)
          check_tcp_parse_msg_type(msg)
          msg
        end

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
          check_tcp_parse_msg(msg)
          body = msg.split(':')[1] || ''
          hash = { type: @msg_type }

          method_str = "parse_tcp_#{@msg_type.downcase}"
          return hash.merge!(data: body) unless respond_to?(method_str, true)
          hash.merge!(send(method_str, body))
        end
      end
    end
  end
end
