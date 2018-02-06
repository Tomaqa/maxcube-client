require 'base64'
require 'stringio'
require 'date'

module MaxCube
  # Structure of message:
  # * Starts with single letter followed by ':'
  # * Ends with "\r\n"
  # Example (unencoded):
  # X:message\r\n
  # As all messages are being split by "\r\n",
  # it does not occur in single message processing,
  # only in raw data processing.
  class MessageHandler
    # Without "\r\n", with it it is 1900
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
      def initialize(msg_type, info = 'invalid message type')
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
      msg
    end

    # Check single message validity, already without "\r\n" at the end
    def valid_msg(msg)
      valid_msg_length(msg) && msg =~ /\A[[:alpha:]]:[[:print:]]*\z/
    end

    def check_msg(msg)
      check_msg_length(msg)
      raise InvalidMessageFormat unless valid_msg(msg)
      msg
    end

    def valid_data_type(raw_data)
      raw_data.is_a?(String)
    end

    def check_data_type(raw_data)
      raise TypeError unless valid_data_type(raw_data)
      raw_data
    end

    def valid_data(raw_data)
      return true if raw_data.empty?
      raw_data[0..1] != "\r\n" && raw_data.chars.last(2).join == "\r\n"
    end

    def check_data(raw_data)
      # check_data_type(raw_data)
      raise InvalidMessageFormat unless valid_data(raw_data)
      raw_data
    end

    private

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

    # def check_msg_min_data_length(min_length, length, info)
    #   return unless length < min_length
    #   raise InvalidMessageBody
    #     .new(@msg_type,
    #          "#{info} - remaining data length is insufficient" \
    #          " (#{length} < #{min_length})")
    # end

    # def check_device_type(device_type_id)
    def device_type(device_type_id)
      device_type = DEVICE_TYPE[device_type_id]
      return device_type if device_type
      raise InvalidMessageBody
        .new(@msg_type, "unrecognized device type id: #{device_type_id}")
    end

    def device_type_id(device_type)
      device_type_id = DEVICE_TYPE.index(device_type)
      return device_type_id if device_type_id
      raise InvalidMessageBody
        .new(@msg_type, "unrecognized device type: #{device_type}")
    end

    def device_mode(device_mode_id)
      device_mode = DEVICE_MODE[device_mode_id]
      return device_mode if device_mode
      raise InvalidMessageBody
        .new(@msg_type, "unrecognized device mode id: #{device_mode_id}")
    end

    def device_mode_id(device_mode)
      device_mode_id = DEVICE_MODE.index(device_mode)
      return device_mode_id if device_mode_id
      raise InvalidMessageBody
        .new(@msg_type, "unrecognized device mode: #{device_mode}")
    end

    def encode(data)
      Base64.strict_encode64(data)
    end

    def decode(data)
      Base64.decode64(data)
    end

  end

  class MessageParser < MessageHandler
    MSG_TYPES = %w[H F L C M N A E D b g j p o v w S].freeze

    def valid_parse_msg_type(msg)
      msg_type = msg[0]
      return msg_type if MSG_TYPES.include?(msg_type)
      false
    end

    def check_parse_msg_type(msg)
      @msg_type = valid_parse_msg_type(msg)
      return if @msg_type
      raise InvalidMessageType.new(msg[0])
    end

    # Check single message validity, which is already without "\r\n"
    def valid_parse_msg(msg)
      valid_msg(msg) && valid_parse_msg_type(msg)
    end

    def check_parse_msg(msg)
      check_msg(msg)
      check_parse_msg_type(msg)
      msg
    end

    def read(count, unpack = '')
      raise IOError if @io.size - @io.pos < count
      str = @io.read(count)
      unpack.empty? ? str : str.unpack1(unpack)
    end

    # Process set of messages - raw data separated by "\r\n"
    # @param [String, #read] raw data from a Cube
    # @return [Array<Hash>] particular message contents
    def parse_data(raw_data)
      check_data(raw_data)
      raw_data.split("\r\n").map(&method(:parse_msg))
    end

    # Parse single message already without "\r\n"
    # @param [String, #read] single message data without "\r\n"
    # @return [Hash] particular message parts separated into hash,
    #                which should be human readable
    def parse_msg(msg)
      check_parse_msg(msg)
      body = msg.split(':')[1] || ''
      hash = { type: @msg_type }
      method = self.method("parse_#{@msg_type.downcase}")
      hash.merge(method.call(body))
    rescue NameError
      hash[:data] = body
      hash
    end

    require_relative 'a_message'
    require_relative 'c_message'
    require_relative 'f_message'
    require_relative 'h_message'
    require_relative 'l_message'
    require_relative 'm_message'
    require_relative 'n_message'
    require_relative 's_message'
  end

  class MessageSerializer < MessageHandler
    MSG_TYPES = %w[u i s m n x g q e d B G J P O V W a r t l c v f z].freeze

    def valid_serialize_msg_type(hash)
      msg_type = hash[:type]
      return msg_type if msg_type &&
                         msg_type.length == 1 &&
                         MSG_TYPES.include?(msg_type)
      false
    end

    def check_serialize_msg_type(hash)
      @msg_type = valid_serialize_msg_type(hash)
      return if @msg_type
      raise InvalidMessageType.new(hash[:type])
    end

    def valid_serialize_hash(hash)
      valid_serialize_msg_type(hash)
    end

    def check_serialize_hash(hash)
      check_serialize_msg_type(hash)
    end

    # Send set of messages separated by "\r\n"
    # @param [Array<Hash>] particular message contents
    # @return [String] raw data for a Cube
    def serialize_data(hashes)
      raw_data = hashes.map(&method(:serialize_hash)).join
      check_data(raw_data)
    end

    # Serialize data from hash into message with "\r\n" at the end
    # @param [Hash, #read] particular human readable message parts
    #                      (it is assumed to contain valid data)
    # @return [String] single message data with "\r\n" at the end
    def serialize_hash(hash)
      check_serialize_hash(hash)
      msg = "#{@msg_type}:"
      method = self.method("serialize_#{@msg_type.downcase}")
      msg << method.call(hash)
      check_msg(msg) << "\r\n"
    rescue NameError
      raise InvalidMessageType
        .new(@msg_type, 'message type is not implemented yet')
    end

    require_relative 'a_message'
    require_relative 'c_message'
    require_relative 'f_message'
    require_relative 'l_message'
    require_relative 'm_message'
    require_relative 'n_message'
    require_relative 'q_message'
    require_relative 's_message'
    require_relative 't_message'
    require_relative 'u_message'
    require_relative 'z_message'
  end
end
