require 'maxcube/messages/tcp'
require 'maxcube/messages/handler'

module MaxCube
  module Messages
    module TCP
      # Extends {Messages::Handler} of routines connected to TCP Cube messages.
      module Handler
        include Messages::Handler

        # Validates whether message satisfies {MSG_MAX_LEN}.
        # @param msg [String] input message.
        # @return [Boolean] whether message length is valid.
        def valid_tcp_msg_length(msg)
          msg.length.between?(2, MSG_MAX_LEN)
        end

        # As {#valid_tcp_msg_length}, but raises exception
        # if message length is not valid.
        # @param msg [String] input message.
        # @return [Integer] message length.
        # @raise [InvalidMessageLength] if message length is not valid.
        def check_tcp_msg_length(msg)
          raise InvalidMessageLength unless valid_tcp_msg_length(msg)
          msg.length
        end

        # Validates whether message satisfies TCP Cube format (see {TCP}).
        # @param msg [String] input message.
        # @return [Boolean] whether message format is valid.
        def valid_tcp_msg_format(msg)
          msg =~ /\A[[:alpha:]]:[[:print:]]*\z/
        end

        # As {#valid_tcp_msg_format}, but raises exception
        # if message format is not valid.
        # @param msg [String] input message.
        # @return [String] input message.
        # @raise [InvalidMessageFormat] if message format is not valid.
        def check_tcp_msg_format(msg)
          raise InvalidMessageFormat unless valid_tcp_msg_format(msg)
          msg
        end

        # Validates whether given message is a valid TCP Cube message.
        # It calls {#valid_tcp_msg_length},
        # {#valid_tcp_msg_format} and {#valid_msg}.
        # @param msg [String] input message.
        # @return [Boolean] whether message is valid.
        def valid_tcp_msg(msg)
          valid_tcp_msg_length(msg) &&
            valid_tcp_msg_format(msg) &&
            valid_msg(msg)
        end

        # As {#valid_tcp_msg}, but raises exception if message is not valid.
        # It calls {#check_tcp_msg_length},
        # {#check_tcp_msg_format} and {#check_msg}.
        # @param msg [String] input message.
        # @return [String] input message.
        def check_tcp_msg(msg)
          check_tcp_msg_length(msg)
          check_tcp_msg_format(msg)
          check_msg(msg)
          msg
        end

        # Validates whether given hash with message contents
        # is valid for TCP Cube messaging purposes.
        # It only calls {#valid_hash}.
        # @param hash [Hash] input hash.
        # @return [Boolean] whether hash is valid.
        def valid_tcp_hash(hash)
          valid_hash(hash)
        end

        # As {#valid_tcp_hash}, but raises exception if hash is not valid.
        # It only calls {#check_hash}.
        # @param hash [Hash] input hash.
        # @return [Hash] input hash.
        def check_tcp_hash(hash)
          check_hash(hash)
          hash
        end

        # Validates whether input raw data
        # containing multiple separated TCP Cube messages is valid.
        # It only checks +\\r\\\n+ stuff.
        # It does not validate data type ({#valid_data_type}), yet?
        # It does not validate particular messages.
        # @param raw_data [String] input data with multiple separated messages.
        # @return [Boolean] whether input data is valid.
        def valid_tcp_data(raw_data)
          return true if raw_data.empty?
          raw_data[0..1] != "\r\n" && raw_data.chars.last(2).join == "\r\n"
        end

        # As {#valid_tcp_data}, but raises exception if raw data is not valid.
        # @param raw_data [String] input data with multiple separated messages.
        # @return [String] input data.
        # @raise [InvalidMessageFormat] if input data is not valid.
        def check_tcp_data(raw_data)
          raise InvalidMessageFormat unless valid_tcp_data(raw_data)
          raw_data
        end

        private

        # Tells how to get message type from a message.
        # @param msg [String] input message.
        # @return [String] message type.
        def msg_msg_type(msg)
          msg.chr
        end
      end
    end
  end
end
