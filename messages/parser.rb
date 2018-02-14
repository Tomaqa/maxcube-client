require_relative 'handler'

module MaxCube
  module Messages
    module Parser
      include Handler

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
    end
  end
end
