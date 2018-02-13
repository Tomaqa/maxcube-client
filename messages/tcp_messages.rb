module MaxCube
  class Messages
    # Structure of message:
    # * Starts with single letter followed by ':'
    # * Ends with "\r\n"
    # Example (unencoded):
    # X:message\r\n
    # As all messages are being split by "\r\n",
    # it does not occur in single message processing,
    # only in raw data processing.
    module TCP
      # Without "\r\n", with it it is 1900
      MSG_MAX_LEN = 1898

      def valid_tcp_msg_length(msg)
        msg.length.between?(2, MSG_MAX_LEN)
      end
      alias valid_msg_length valid_tcp_msg_length

      def check_tcp_msg_length(msg)
        raise InvalidMessageLength unless valid_tcp_msg_length(msg)
        msg
      end

      # Check single message validity, already without "\r\n" at the end
      def valid_tcp_msg(msg)
        valid_tcp_msg_length(msg) && msg =~ /\A[[:alpha:]]:[[:print:]]*\z/
      end
      alias valid_msg valid_tcp_msg

      def check_tcp_msg(msg)
        check_tcp_msg_length(msg)
        raise InvalidMessageFormat unless valid_tcp_msg(msg)
        msg
      end

      def valid_tcp_data(raw_data)
        return true if raw_data.empty?
        raw_data[0..1] != "\r\n" && raw_data.chars.last(2).join == "\r\n"
      end
      alias valid_data valid_tcp_data

      def check_tcp_data(raw_data)
        # check_data_type(raw_data)
        raise InvalidMessageFormat unless valid_tcp_data(raw_data)
        raw_data
      end
    end
  end
end