require_relative 'handler'

module MaxCube
  module Messages
    module Serializer
      include Handler

      def valid_serial_hash_values(hash)
        hash.none? { |_, v| v.nil? }
      end

      def check_serial_hash_values(hash)
        return if valid_serial_hash_values(hash)
        hash = hash.dup
        hash.delete(:type)
        raise InvalidMessageBody
          .new(@msg_type, "invalid hash values: #{hash}")
      end

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
