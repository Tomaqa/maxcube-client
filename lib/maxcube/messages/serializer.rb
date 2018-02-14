require_relative 'handler'

module MaxCube
  module Messages
    module Serializer
      include Handler

      def serialize(*args, esize: 0, size: 0, ocount: 0)
        return args.join if size.zero? && esize.zero?

        ocount, subcount, subsize = serialize_bounds(args,
                                                     esize: esize,
                                                     size: size,
                                                     ocount: ocount)
        str = ''
        args.reverse!
        ocount.times do
          str << args.pop while args.last.is_a?(String)
          substr = args.pop(subcount).pack(PACK_FORMAT[subsize])
          substr = substr[1..-1] if subsize == 3
          str << substr
        end
        str << args.pop until args.empty?

        str
      end

      def write(*args, esize: 0, size: 0, ocount: 0)
        @io.write(serialize(*args, esize: esize, size: size, ocount: ocount))
      end

      def serialize_hash_body(hash, serializer_type_str)
        method_str = "serialize_#{serializer_type_str}_#{@msg_type.downcase}"
        return send(method_str, hash) if respond_to?(method_str, true)
        raise InvalidMessageType
          .new(@msg_type, 'serialization of message type' \
                          ' is not implemented (yet)')
      end

      private

      def serialize_bounds(args, esize: 0, size: 0, ocount: 0)
        icount = args.size - args.count { |a| a.is_a?(String) }
        return 0 if icount.zero?
        if esize.zero?
          ocount = icount if ocount.zero?
          subsize = size / ocount
        else
          size = icount * esize
          ocount = size / esize
          subsize = esize
        end
        subcount = icount / ocount

        [ocount, subcount, subsize]
      end
    end
  end
end
