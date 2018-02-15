require_relative 'handler'
require 'maxcube/messages/serializer'

module MaxCube
  module Messages
    module UDP
      # Extends {Messages::Serializer} and {UDP::Handler} of routines
      # connected to UDP Cube messages serializing.
      class Serializer
        include UDP::Handler
        include Messages::Serializer

        # Known message types in the direction client -> Cube.
        MSG_TYPES = %w[I N h c R].freeze

        # {UDP::MSG_PREFIX} with a suffix.
        MSG_PREFIX = (UDP::MSG_PREFIX + "*\x00").freeze

        # Serializes data from a single hash
        # into UDP Cube message.
        # Calls {#check_udp_hash} at the begin
        # and {#check_udp_msg} at the end.
        # @param hash [Hash] particular message contents separated into hash.
        # @option hash [String] :serial_number if not specified,
        #   it is set to universal value.
        #   It is used for broadcast messages.
        # @return [String] output message.
        def serialize_udp_hash(hash)
          check_udp_hash(hash)
          serial_number = hash[:serial_number] || '*' * 10
          msg = MSG_PREFIX + serial_number << @msg_type
          check_udp_msg(msg)
        end

        private

        # Tells how to get message type from a message.
        # @param msg [String] input message.
        # @return [String] message type.
        def msg_msg_type(msg)
          msg[18]
        end
      end
    end
  end
end
