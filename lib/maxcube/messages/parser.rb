require_relative 'handler'

module MaxCube
  module Messages
    # This module provides methods connected to message parsing only
    # (i.e. direction Cube -> client).
    module Parser
      include Handler

      # This method should be used each time any +IO+ is read,
      # which is very useful for parsing purposes.
      # It contains optional implicit conversion
      # of binary string data of certain length into integers
      # (using {PACK_FORMAT})
      # or into any other explicit format that String#unpack understands.
      # In addition, it checks whether the read operation succeeded
      # and raises an exception if not
      # (this is useful when parsing a message of a specified format).
      # @param count [Integer] number of bytes to read.
      #   0 causes to read until EOF.
      # @param unpack [Boolean, String] if +true+
      #   it does implicit conversion to integer;
      #   if String, the format is passed to String#unpack as is.
      # @return [String, Integer] read data; its type depends on +unpack+.
      # @raise [IOError] if reading failed (incl. that nothing was read).
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

      # Parses message body, i.e. at least message type is already decoded.
      # It dynamically calls method corresponding to message and parser type.
      # If message type is not implemented yet, read data is stored as is.
      # It transforms unhandled +IOError+ exceptions
      # (probably raised from {#read}) to {InvalidMessageBody}.
      # @param body [String] message body to be parsed.
      # @param hash [Hash] hash to store parsed data into.
      #   It should already contain contents of message head.
      #   Hash will be modified.
      # @param parser_type [String] parser type contained in method identifiers.
      # @return [Hash, nil] resulting hash, or +nil+ in case
      #   the message type is not implemented yet.
      # @raise [InvalidMessageBody] if +IOError+ catched.
      def parse_msg_body(body, hash, parser_type)
        method_str = "parse_#{parser_type}_#{@msg_type.downcase}"
        if respond_to?(method_str, true)
          return hash.merge!(send(method_str, body))
        end
        hash[:data] = body
        nil
      rescue IOError
        raise InvalidMessageBody
          .new(@msg_type, 'unexpected EOF reached')
      end
    end
  end
end
