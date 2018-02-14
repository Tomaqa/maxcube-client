require_relative 'tcp'
require_relative '../handler'

module MaxCube
  module Messages
    module TCP
      module Handler
        include Messages::Handler

        def valid_tcp_msg_length(msg)
          msg.length.between?(2, MSG_MAX_LEN)
        end

        def check_tcp_msg_length(msg)
          raise InvalidMessageLength unless valid_tcp_msg_length(msg)
          msg
        end

        # Check single message validity, already without "\r\n" at the end
        def valid_tcp_msg(msg)
          valid_tcp_msg_length(msg) && msg =~ /\A[[:alpha:]]:[[:print:]]*\z/
        end

        def check_tcp_msg(msg)
          check_tcp_msg_length(msg)
          raise InvalidMessageFormat unless valid_tcp_msg(msg)
          msg
        end

        def valid_tcp_data(raw_data)
          return true if raw_data.empty?
          raw_data[0..1] != "\r\n" && raw_data.chars.last(2).join == "\r\n"
        end

        def check_tcp_data(raw_data)
          # check_data_type(raw_data)
          raise InvalidMessageFormat unless valid_tcp_data(raw_data)
          raw_data
        end
      end
    end
  end
end
