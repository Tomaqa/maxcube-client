require 'maxcube/messages/udp'
require 'maxcube/messages/handler'

module MaxCube
  module Messages
    module UDP
      # Extends {Messages::Handler} of routines connected to UDP Cube messages.
      module Handler
        include Messages::Handler

        # Validates whether message contains correct {MSG_PREFIX}
        # (suffix of the prefix differs for parser and serializer).
        # @param msg [String] input message.
        # @return [Boolean] whether message prefix is valid.
        def valid_udp_msg_prefix(msg)
          msg.start_with?(self.class.const_get('MSG_PREFIX'))
        end

        # As {#valid_udp_msg_prefix},
        # but it raises exception if the prefix is not valid.
        # @param msg [String] input message.
        # @return [String] input message.
        # @raise [InvalidMessageFormat] if the prefix is not valid.
        def check_udp_msg_prefix(msg)
          raise InvalidMessageFormat unless valid_udp_msg_prefix(msg)
          msg
        end

        # Validates whether given message is a valid UDP Cube message.
        # It calls {#valid_udp_msg_prefix} and {#valid_msg}.
        # @param msg [String] input message.
        # @return [Boolean] whether message is valid.
        def valid_udp_msg(msg)
          valid_udp_msg_prefix(msg) &&
            valid_msg(msg)
        end

        # As {#valid_udp_msg}, but raises exception if message is not valid.
        # It calls {#check_udp_msg_prefix} and {#check_msg}.
        # @param msg [String] input message.
        # @return [String] input message.
        def check_udp_msg(msg)
          check_udp_msg_prefix(msg)
          check_msg(msg)
          msg
        end

        # Validates whether given hash with message contents
        # is valid for UDP Cube messaging purposes.
        # It only calls {#valid_hash}.
        # @param hash [Hash] input hash.
        # @return [Boolean] whether hash is valid.
        def valid_udp_hash(hash)
          valid_hash(hash)
        end

        # As {#valid_udp_hash}, but raises exception if hash is not valid.
        # It only calls {#check_hash}.
        # @param hash [Hash] input hash.
        # @return [Hash] input hash.
        def check_udp_hash(hash)
          check_hash(hash)
          hash
        end
      end
    end
  end
end
