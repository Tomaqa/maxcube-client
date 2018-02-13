module MaxCube
  class Messages
    module Parser
      module TCP
        MSG_TYPES = %w[H F L C M N A E D b g j p o v w S].freeze

        def valid_tcp_parse_msg_type(msg)
          msg_type = msg.chr
          return msg_type if MSG_TYPES.include?(msg_type)
          false
        end
        alias valid_parse_msg_type valid_tcp_parse_msg_type

        def check_tcp_parse_msg_type(msg)
          @msg_type = valid_tcp_parse_msg_type(msg)
          return if @msg_type
          raise InvalidMessageType.new(msg.chr)
        end

        # Check single message validity, which is already without "\r\n"
        def valid_tcp_parse_msg(msg)
          valid_tcp_msg(msg) && valid_tcp_parse_msg_type(msg)
        end
        alias valid_parse_msg valid_tcp_parse_msg

        def check_tcp_parse_msg(msg)
          check_tcp_msg(msg)
          check_tcp_parse_msg_type(msg)
          msg
        end

        def read(count = 0, unpack = false)
          str = if count.zero?
                  @io.read
                else
                  raise IOError if @io.size - @io.pos < count
                  @io.read(count)
                end
          return str unless unpack
          str = "\x00".b + str if count == 3
          unpack = PACK_FORMAT[count] unless unpack.is_a?(String)
          str.unpack1(unpack)
        end

        # Process set of messages - raw data separated by "\r\n"
        # @param [String, #read] raw data from a Cube
        # @return [Array<Hash>] particular message contents
        def parse_tcp_data(raw_data)
          check_tcp_data(raw_data)
          raw_data.split("\r\n").map(&method(:parse_tcp_msg))
        end
        alias parse_data parse_tcp_data

        # Parse single message already without "\r\n"
        # @param [String, #read] single message data without "\r\n"
        # @return [Hash] particular message parts separated into hash,
        #                which should be human readable
        def parse_tcp_msg(msg)
          check_tcp_parse_msg(msg)
          body = msg.split(':')[1] || ''
          hash = { type: @msg_type }

          method_str = "parse_#{@msg_type.downcase}"
          return hash.merge!(data: body) unless respond_to?(method_str, true)
          hash.merge!(send(method_str, body))
        end
        alias parse_msg parse_tcp_msg

        require_relative 'a_message'
        require_relative 'c_message'
        require_relative 'f_message'
        require_relative 'h_message'
        require_relative 'l_message'
        require_relative 'm_message'
        require_relative 'n_message'
        require_relative 's_message'
      end
    end
  end
end