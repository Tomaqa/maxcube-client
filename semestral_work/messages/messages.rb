require 'base64'
require 'stringio'
require 'date'

module MaxCube
  # Structure of message:
  # * Starts with single letter followed by ':'
  # * Ends with '\r\n'
  # Example (unencoded):
  # X:message\r\n
  # As all messages are being split by '\r\n',
  # it does not occur in single message processing,
  # only in raw data processing
  class MessageHandler
    # Without '\r\n', with it it is 1900
    MSG_MAX_LEN = 1898

    DEVICE_MODE = %i[auto manual vacation boost].freeze
    DEVICE_TYPE = %i[cube
                     radiator_thermostat radiator_thermostat_plus
                     wall_thermostat
                     shutter_contact eco_button].freeze

    DAYS_OF_WEEK = %w[Saturday Sunday Monday
                      Tuesday Wednesday Thursday Friday].freeze

    class InvalidMessage < RuntimeError; end

    class InvalidMessageLength < InvalidMessage
      def initialize(info = 'invalid message length')
        super
      end
    end

    class InvalidMessageFormat < InvalidMessage
      def initialize(info = 'invalid format')
        super
      end
    end

    class InvalidMessageType < InvalidMessage
      def initialize(msg_type, info = 'unknown message type')
        super("#{info}: #{msg_type}")
      end
    end

    class InvalidMessageBody < InvalidMessage
      def initialize(msg_type, info = 'invalid format')
        super("message type #{msg_type}: #{info}")
      end
    end

    def valid_msg_length(msg)
      msg.length.between?(2, MSG_MAX_LEN)
    end

    def check_msg_length(msg)
      raise InvalidMessageLength unless valid_msg_length(msg)
    end

    # Check single message validity, already without '\r\n' at the end
    def valid_msg(msg)
      valid_msg_length(msg) && msg =~ /^[[:alpha:]]:[^:]*$/
    end

    def check_msg(msg)
      check_msg_length(msg)
      raise InvalidMessageFormat unless valid_msg(msg)
    end

    def valid_data_type(raw_data)
      raw_data.is_a?(String)
    end

    def check_data_type(raw_data)
      raise TypeError unless valid_data_type(raw_data)
    end

    private

    def check_data(raw_data)
      # check_data_type(raw_data)
    end

    def valid_msg_part_lengths(lengths, *args)
      return false if args.any?(&:nil?) ||
                      args.length < lengths.length
      args.each_with_index.all? do |v, i|
        !lengths[i] || v.length == lengths[i]
      end
    end

    def check_msg_part_lengths(lengths, *args)
      return if valid_msg_part_lengths(lengths, *args)
      raise InvalidMessageBody
        .new(@msg_type,
             "invalid lengths of message parts #{args}" \
             " (lengths should be: #{lengths})")
    end

    # Convert string of characters (not binary data!) to hex number
    # For binary data use #String.unpack
    def hex_to_i_check(info, *args)
      if args.all? { |x| x && !x[/\H/] && !x[/^$/] }
        return args.map { |x| x.to_i(16) }
      end
      raise InvalidMessageBody
        .new(@msg_type,
             "invalid hex format of message parts #{args}" \
             " (#{info})")
    end

    def check_msg_min_data_length(min_length, length, info)
      return unless length < min_length
      raise InvalidMessageBody
        .new(@msg_type,
             "#{info} - remaining data length is insufficient" \
             " (#{length} < #{min_length})")
    end

    def encode(data)
      Base64.encode64(data)
      # Base64.strict_encode64(data)
    end

    def decode(data)
      Base64.decode64(data)
      # Base64.strict_decode64(data)
    end

  end

  class MessageReceiver < MessageHandler
    MSG_TYPES = %w[H F L C M N A E D b g j p o v w S].freeze

    def valid_recv_msg_type(msg)
      msg_type = msg[0]
      return msg_type if MSG_TYPES.include?(msg_type)
      false
    end

    def check_recv_msg_type(msg)
      @msg_type = valid_recv_msg_type(msg)
      return if @msg_type
      raise InvalidMessageType.new(msg[0])
    end

    # Check single message validity, which is already without '\r\n'
    def valid_recv_msg(msg)
      valid_msg(msg) && valid_recv_msg_type(msg)
    end

    def check_recv_msg(msg)
      check_msg(msg)
      check_recv_msg_type(msg)
    end

    def read(count, unpack = '')
      raise IOError if @io.size - @io.pos < count
      str = @io.read(count)
      unpack.empty? ? str : str.unpack1(unpack)
    end

    # Process set of messages - raw data separated by '\r\n'
    # @param [String, #read] raw data from a Cube
    # @return [Array<Hash>] particular message contents
    def recv_data(raw_data)
      check_data(raw_data)
      raw_data.split("\r\n").map(&method(:recv_msg)).to_a
    end

    # Parse single message already without '\r\n'
    # @param [String, #read] single message data without '\r\n'
    # @return [Hash] particular message parts separated into hash
    def recv_msg(msg)
      check_recv_msg(msg)
      body = msg.split(':')[1] || ''
      { type: @msg_type }.merge(send("parse_#{@msg_type.downcase}", body))
    end

    require_relative 'a_message'
    require_relative 'c_message'
    require_relative 'h_message'
    require_relative 'l_message'
    require_relative 'm_message'
  end

  class MessageSender < MessageHandler
    MSG_TYPES = %w[u i s m n x g q e d B G J P O V W a r t w l c v f z].freeze
  end
end

# p MaxCube::MessageReceiver.new.recv_data('')
# p MaxCube::MessageReceiver.new.recv_data("\r\n")
# p MaxCube::MessageReceiver.new.recv_data("\r\n\r\n")
# MaxCube::MessageReceiver.new.recv_data(':')
# MaxCube::MessageReceiver.new.recv_data('H:')
# MaxCube::MessageReceiver.new.recv_data('M:00,01,')
# MaxCube::MessageReceiver.new.recv_data('M:00,01,'+Base64.encode64('abcd'))
# p MaxCube::MessageReceiver.new.recv_data('M:00,01,'+Base64.encode64('ab192XY123'))
# p MaxCube::MessageReceiver.new.recv_data('M:00,01,'+Base64.encode64('ab192XY1230'))
# p MaxCube::MessageReceiver.new.recv_data('M:00,01,'+Base64.encode64("ab\x01!\x02XY123\x00"))
# p MaxCube::MessageReceiver.new.recv_data("M:00,01,VgIEAQNCYWQK7WkCBEJ1cm8K8wADCldvaG56aW1tZXIK8wwEDFNjaGxhZnppbW1lcgr
# 1QAUCCu1pS0VRMDM3ODA0MAZIVCBCYWQBAgrzAEtFUTAzNzk1NDQHSFQgQnVybwICCvMMS0VRMD
# M3OTU1NhlIVCBXb2huemltbWVyIEJhbGtvbnNlaXRlAwIK83lLRVEwMzc5NjY1GkhUIFdvaG56a
# W1tZXIgRmVuc3RlcnNlaXRlAwIK9UBLRVEwMzgwMTIwD0hUIFNjaGxhZnppbW1lcgQB\r\n")
# p MaxCube::MessageReceiver.new.recv_data('L:Cw/a7QkSGBgoAMwACw/DcwkSGBgoAM8ACw/DgAkSGBgoAM4A')
# p MaxCube::MessageReceiver.new.recv_data('L:' + Base64.strict_encode64("\x0b\x0f\xda\xed\x09\x00\x00\x18\x18\x01\x00\x00"))
# p MaxCube::MessageReceiver.new.recv_data('L:' + Base64.strict_encode64("\x00"))
# p MaxCube::MessageReceiver.new.recv_data('L:' + Base64.strict_encode64("\x0a\x0f\xda\xed\x09\x00\x00\x18\x18\x01\x00\x00"))
# p MaxCube::MessageReceiver.new.recv_data('L:' + Base64.strict_encode64("\x0c\x0f\xda\xed\x09\x00\x00\x18\x18\x01\x00\x00\x00"))
# p MaxCube::MessageReceiver.new.recv_data('C:03f25d,7QPyXQATAQBKRVEwNTQ0OTIzAAsABEAAAAAAAAAAAPIA==')

