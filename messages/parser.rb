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

      def parse_msg_body(body, hash, parser_type_str)
        method_str = "parse_#{parser_type_str}_#{@msg_type.downcase}"
        if respond_to?(method_str, true)
          return hash.merge!(send(method_str, body))
        end
        hash[:data] = body
        nil
      end
    end
  end
end
