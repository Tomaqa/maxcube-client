require_relative 'handler'

module MaxCube
  module Messages
    # This module provides methods connected to message serializing only
    # (i.e. direction client -> Cube).
    module Serializer
      include Handler

      # Serializes input +args+ into String,
      # with optional implicit conversion from integer into binary string
      # (using {PACK_FORMAT}).
      # In any case, String elements are serialized as they are.
      # @param args [Array<String, Integer>] input arguments.
      # @param esize [Integer] output size of binary string
      #   of each converted integer element.
      #   Nonzero value enables conversion of integers into binary strings.
      #   This value is sufficient alone, but it is not suitable in cases
      #   when more elements are to be grouped together -
      #   +esize+ is in interval (0,1) in this case.
      #   Output count (+count+) is assumed to be the same with input count.
      # @param size [Integer] total output size of binary string
      #   of converted integer elements.
      #   Nonzero value enables conversion of integers into binary strings.
      #   This value is sufficient alone
      #   if output count is same with input count.
      # @param count [Integer] output count of converted integer elements.
      #   +size+ must be specified. 0 means same count as input count.
      #   It is suitable for cases when input and output counts differ.
      # @return [String] serialized +args+. If conversion was enabled,
      #   it may contain binary data.
      def serialize(*args, esize: 0, size: 0, count: 0)
        return args.join if size.zero? && esize.zero?

        count, subcount, subsize = serialize_bounds(args,
                                                    esize: esize,
                                                    size: size,
                                                    count: count)
        str = ''
        args.reverse!
        count.times do
          str << args.pop while args.last.is_a?(String)
          substr = args.pop(subcount).pack(PACK_FORMAT[subsize])
          substr = substr[1..-1] if subsize == 3
          str << substr
        end
        str << args.pop until args.empty?

        str
      end

      # It serializes +args+ with {#serialize}
      # and writes it into internal +IO+ variable.
      def write(*args, esize: 0, size: 0, count: 0)
        @io.write(serialize(*args, esize: esize, size: size, count: count))
      end

      # Serializes message body,
      # i.e. message head has been already serialized.
      # It dynamically calls method corresponding to message
      # and serializer type.
      # If message type is not implemented yet,
      # it is unclear how to serialize the +hash+,
      # so an exception is raised.
      # @param hash [Hash] hash with message contents to serialize.
      # @param serializer_type [String] serializer type
      #   contained in method identifiers.
      # @return [String] resulting message string.
      # @raise [InvalidMessageType] if the message type is not implemented yet.
      def serialize_hash_body(hash, serializer_type)
        method_str = "serialize_#{serializer_type}_#{@msg_type.downcase}"
        return send(method_str, hash) if respond_to?(method_str, true)
        raise InvalidMessageType
          .new(@msg_type, 'serialization of message type' \
                          ' is not implemented (yet)')
      end

      private

      # Helper method called by {#serialize}
      # that evaluates necessary counts and sizes
      # for purposes of integer elements conversion in loop.
      # @return [[count, subcount, subsize]]
      #   +count+ is output count of converted elements
      #   (0 if +args+ array is empty),
      #   +subcount+ is number of elements
      #   to be converted together in each step,
      #   +subsize+ is output size in bytes
      #   to which to convert elements in each step into.
      def serialize_bounds(args, esize: 0, size: 0, count: 0)
        icount = args.size - args.count { |a| a.is_a?(String) }
        return 0 if icount.zero?
        if esize.zero?
          count = icount if count.zero?
          subsize = size / count
        else
          size = icount * esize
          count = size / esize
          subsize = esize
        end
        subcount = icount / count

        [count, subcount, subsize]
      end
    end
  end
end
