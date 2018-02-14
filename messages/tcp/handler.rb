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
          msg.length
        end

        def valid_tcp_msg_format(msg)
          msg =~ /\A[[:alpha:]]:[[:print:]]*\z/
        end

        def check_tcp_msg_format(msg)
          raise InvalidMessageFormat unless valid_tcp_msg_format(msg)
          msg
        end

        # Check single message validity, already without "\r\n" at the end
        def valid_tcp_msg(msg)
          valid_tcp_msg_length(msg) &&
            valid_tcp_msg_format(msg) &&
            valid_msg(msg)
        end

        def check_tcp_msg(msg)
          check_tcp_msg_length(msg)
          check_tcp_msg_format(msg)
          check_msg(msg)
          msg
        end

        def valid_tcp_hash(hash)
          valid_hash(hash)
        end

        def check_tcp_hash(hash)
          check_hash(hash)
          hash
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

        private

        def msg_msg_type(msg)
          msg.chr
        end
      end
    end
  end
end
