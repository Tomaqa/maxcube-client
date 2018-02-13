# require_relative 'handler'

# module MaxCube
#   class MessageParser < MessageHandler
#     MSG_TYPES = %w[H F L C M N A E D b g j p o v w S].freeze

#     def valid_parse_msg_type(msg)
#       msg_type = msg.chr
#       return msg_type if MSG_TYPES.include?(msg_type)
#       false
#     end

#     def check_parse_msg_type(msg)
#       @msg_type = valid_parse_msg_type(msg)
#       return if @msg_type
#       raise InvalidMessageType.new(msg.chr)
#     end

#     # Check single message validity, which is already without "\r\n"
#     def valid_parse_msg(msg)
#       valid_msg(msg) && valid_parse_msg_type(msg)
#     end

#     def check_parse_msg(msg)
#       check_msg(msg)
#       check_parse_msg_type(msg)
#       msg
#     end

#     def read(count = 0, unpack = false)
#       str = if count.zero?
#               @io.read
#             else
#               raise IOError if @io.size - @io.pos < count
#               @io.read(count)
#             end
#       return str unless unpack
#       str = "\x00".b + str if count == 3
#       unpack = PACK_FORMAT[count] unless unpack.is_a?(String)
#       str.unpack1(unpack)
#     end

#     # Process set of messages - raw data separated by "\r\n"
#     # @param [String, #read] raw data from a Cube
#     # @return [Array<Hash>] particular message contents
#     def parse_data(raw_data)
#       check_data(raw_data)
#       raw_data.split("\r\n").map(&method(:parse_msg))
#     end

#     # Parse single message already without "\r\n"
#     # @param [String, #read] single message data without "\r\n"
#     # @return [Hash] particular message parts separated into hash,
#     #                which should be human readable
#     def parse_msg(msg)
#       check_parse_msg(msg)
#       body = msg.split(':')[1] || ''
#       hash = { type: @msg_type }

#       method_str = "parse_#{@msg_type.downcase}"
#       return hash.merge!(data: body) unless respond_to?(method_str, true)
#       hash.merge!(send(method_str, body))
#     end

#     require_relative 'a_message'
#     require_relative 'c_message'
#     require_relative 'f_message'
#     require_relative 'h_message'
#     require_relative 'l_message'
#     require_relative 'm_message'
#     require_relative 'n_message'
#     require_relative 's_message'
#   end
# end

require_relative 'tcp_messages'
require_relative 'tcp_parser'

module MaxCube
  class Messages
    include TCP

    module Parser
      include TCP
    end
  end
end
