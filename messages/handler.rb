require 'base64'
require 'date'
require 'stringio'

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
                     shutter_contact eco_switch].freeze

    DAYS_OF_WEEK = %w[Saturday Sunday Monday
                      Tuesday Wednesday Thursday Friday].freeze

    PACK_FORMAT = %w[x C n N N].freeze

    class InvalidMessage < RuntimeError; end

    class InvalidMessageLength < InvalidMessage
      def initialize(info = 'invalid message length')
        super
      end
    end

    class InvalidMessageType < InvalidMessage
      def initialize(msg_type, info = 'invalid message type')
        super("#{info}: #{msg_type}")
      end
    end

    class InvalidMessageFormat < InvalidMessage
      def initialize(info = 'invalid format')
        super
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

    def conv_args(type, info, *args, &block)
      info = info.to_s.tr('_', ' ')
      args.map(&block)
    rescue ArgumentError, TypeError
      raise InvalidMessageBody
        .new(@msg_type,
             "invalid #{type} format of arguments #{args} (#{info})")
    end

    # Convert string of characters (not binary data!) to hex number
    # For binary data use #String.unpack
    def to_ints(base, info, *args)
      base_str = base.zero? ? '' : "(#{base})"
      conv_args("integer#{base_str}", info, *args) { |x| Integer(x, base) }
    end

    def to_int(base, info, arg)
      to_ints(base, info, arg).first
    end

    def to_floats(info, *args)
      conv_args('float', info, *args) { |x| Float(x) }
    end

    def to_float(info, arg)
      to_floats(info, arg).first
    end

    def to_bools(info, *args)
      conv_args('boolean', info, *args) do |arg|
        if arg == !!arg
          arg
        elsif arg.nil?
          false
        elsif %w[true false].include?(arg)
          arg == 'true'
        else
          !Integer(arg).zero?
        end
      end
    end

    def to_bool(info, arg)
      to_bools(info, arg).first
    end

    def to_datetimes(info, *args)
      conv_args('datetime', info, *args) do |arg|
        if arg.is_a?(DateTime)
          arg
        elsif arg.respond_to?('to_datetime')
          arg.to_datetime
        else
          DateTime.parse(arg)
        end
      end
    end

    def to_datetime(info, arg)
      to_datetimes(info, arg).first
    end

    def ary_elem(ary, id, info)
      elem = ary[id]
      return elem if elem
      raise InvalidMessageBody
        .new(@msg_type, "unrecognized #{info} id: #{id}")
    end

    def ary_elem_id(ary, elem, info)
      id = ary.index(elem)
      return id if id
      raise InvalidMessageBody
        .new(@msg_type, "unrecognized #{info}: #{elem}")
    end

    def device_type(device_type_id)
      ary_elem(DEVICE_TYPE, device_type_id, 'device type')
    end

    def device_type_id(device_type)
      ary_elem_id(DEVICE_TYPE, device_type.to_sym, 'device type')
    end

    def device_mode(device_mode_id)
      ary_elem(DEVICE_MODE, device_mode_id, 'device mode')
    end

    def device_mode_id(device_mode)
      ary_elem_id(DEVICE_MODE, device_mode.to_sym, 'device mode')
    end

    def day_of_week(day_id)
      ary_elem(DAYS_OF_WEEK, day_id, 'day of week')
    end

    def day_of_week_id(day)
      if day.respond_to?('to_i') && day.to_i.between?(1, 7)
        return (day.to_i + 1) % 7
      end
      ary_elem_id(DAYS_OF_WEEK, day.capitalize, 'day of week')
    end

    def encode(data)
      Base64.strict_encode64(data)
    end

    def decode(data)
      Base64.decode64(data)
    end
  end
end