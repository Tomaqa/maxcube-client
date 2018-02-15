require 'maxcube'

module MaxCube
  # Encapsulates methods related to Cube messages,
  # i.e. parsing and serializing of TCP/UDP messages.
  # It does not provide any network features.
  module Messages
    # Device modes that determines geating scheduling.
    DEVICE_MODE = %i[auto manual vacation boost].freeze
    # Device types identified in Cube protocol.
    DEVICE_TYPE = %i[cube
                     radiator_thermostat radiator_thermostat_plus
                     wall_thermostat
                     shutter_contact eco_switch].freeze

    # Names of days of week in order Cube protocol uses.
    DAYS_OF_WEEK = %w[Saturday Sunday Monday
                      Tuesday Wednesday Thursday Friday].freeze

    # Base exception class
    # that denotes an error during message parsing/serializing.
    class InvalidMessage < RuntimeError; end

    # Exception class that denotes that message is too short/long.
    class InvalidMessageLength < InvalidMessage
      # @param info contains context information to occured error.
      def initialize(info = 'invalid message length')
        super
      end
    end

    # Exception class that denotes unrecognized message type.
    class InvalidMessageType < InvalidMessage
      # @param msg_type type of message that is being parsed/serialized.
      # @param info contains context information to occured error.
      def initialize(msg_type, info = 'invalid message type')
        super("#{info}: #{msg_type}")
      end
    end

    # Exception class that denotes invalid syntax format of message.
    class InvalidMessageFormat < InvalidMessage
      # @param info contains context information to occured error.
      def initialize(info = 'invalid format')
        super
      end
    end

    # Exception class that denotes that an error occured
    # while parsing/serializing message body,
    # which is specific to message type.
    class InvalidMessageBody < InvalidMessage
      # @param msg_type type of message that is being parsed/serialized.
      # @param info contains context information to occured error.
      def initialize(msg_type, info = 'invalid format')
        super("message type #{msg_type}: #{info}")
      end
    end

    private

    # Applies a block to given arguments
    # in order to perform conversion to certain type.
    # If conversion fails, {InvalidMessageBody} is raised.
    # Thus, this method can be used also for type checking purposes only.
    # @param type [#to_s] name of the type to convert to.
    # @param info [#to_s] context information to pass to raised error.
    # @param args [Array] arguments to be converted into the same type.
    # @yield a rule to provide
    #   certain type check and conversion of arguments.
    # @return [Array] converted elements.
    # @raise [InvalidMessageBody] if conversion fails.
    def conv_args(type, info, *args, &block)
      info = info.to_s.tr('_', ' ')
      args.map(&block)
    rescue ArgumentError, TypeError
      raise InvalidMessageBody
        .new(@msg_type,
             "invalid #{type} format of arguments #{args} (#{info})")
    end

    # Uses {#conv_args} to convert numbers
    # or string of characters (not binary data!)
    # to integers in given base (radix).
    # For binary data use {Parser#read}.
    # @param base [Integer] integers base (radix), 0 means auto-recognition.
    # @param args [Array<#Integer>] arguments to convert to integers.
    # @return [Array<Integer>] converted elements.
    def to_ints(base, info, *args)
      base_str = base.zero? ? '' : "(#{base})"
      conv_args("integer#{base_str}", info, *args) { |x| Integer(x, base) }
    end

    # Uses {#to_ints}, but operates with single argument.
    # @param arg [#Integer] argument to convert to integer.
    # @return [Integer] converted element.
    def to_int(base, info, arg)
      to_ints(base, info, arg).first
    end

    # Uses {#conv_args} to convert numbers
    # or string of characters (not binary data!) to floats.
    # @param args [Array<#Float>] arguments to convert to floats.
    # @return [Array<Float>] converted elements.
    def to_floats(info, *args)
      conv_args('float', info, *args) { |x| Float(x) }
    end

    # Uses {#to_floats}, but operates with single argument.
    # @param arg [#Float] argument to convert to float.
    # @return [Float] converted element.
    def to_float(info, arg)
      to_floats(info, arg).first
    end

    # Uses {#conv_args} to convert objects to bools.
    # @param args [Array] arguments to convert to bools.
    # @return [Array<Boolean>] converted elements
    #   to +TrueClass+ or +FalseClass+.
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

    # Uses {#to_bools}, but operates with single argument.
    # @param arg argument to convert to bool.
    # @return [Boolean] converted element
    #   to +TrueClass+ or +FalseClass+.
    def to_bool(info, arg)
      to_bools(info, arg).first
    end

    # Uses {#conv_args} to convert objects to +Time+.
    # @param args [Array] arguments to convert to +Time+.
    # @return [Array<Time>] converted elements.
    def to_datetimes(info, *args)
      conv_args('datetime', info, *args) do |arg|
        if arg.is_a?(Time)
          arg
        elsif arg.is_a?(String)
          Time.parse(arg)
        elsif arg.respond_to?('to_time')
          arg.to_time
        elsif arg.respond_to?('to_date')
          arg.to_date.to_time
        else
          raise ArgumentError
        end
      end
    end

    # Uses {#to_datetime}, but operates with single argument.
    # @param arg argument to convert to +Time+.
    # @return [Time] converted element.
    def to_datetime(info, arg)
      to_datetimes(info, arg).first
    end

    # Helper method that checks presence of index in array
    # (if not, exception is raised).
    # @param ary [#[]] input container (usually constant).
    # @param id index of element in container.
    # @param info [#to_s] context information to pass to raised error.
    # @return element of container if found.
    # @raise [InvalidMessageBody] if element not found.
    def ary_elem(ary, id, info)
      elem = ary[id]
      return elem if elem
      raise InvalidMessageBody
        .new(@msg_type, "unrecognized #{info} id: #{id}")
    end

    # Reverse method to {#ary_elem}.
    def ary_elem_id(ary, elem, info)
      id = ary.index(elem)
      return id if id
      raise InvalidMessageBody
        .new(@msg_type, "unrecognized #{info}: #{elem}")
    end

    # Uses {#ary_elem} with {DEVICE_TYPE}
    def device_type(device_type_id)
      ary_elem(DEVICE_TYPE, device_type_id, 'device type')
    end

    # Uses {#ary_elem_id} with {DEVICE_TYPE}
    def device_type_id(device_type)
      ary_elem_id(DEVICE_TYPE, device_type.to_sym, 'device type')
    end

    # Uses {#ary_elem} with {DEVICE_MODE}
    def device_mode(device_mode_id)
      ary_elem(DEVICE_MODE, device_mode_id, 'device mode')
    end

    # Uses {#ary_elem_id} with {DEVICE_MODE}
    def device_mode_id(device_mode)
      ary_elem_id(DEVICE_MODE, device_mode.to_sym, 'device mode')
    end

    # Uses {#ary_elem} with {DAYS_OF_WEEK}
    def day_of_week(day_id)
      ary_elem(DAYS_OF_WEEK, day_id, 'day of week')
    end

    # Uses {#ary_elem_id} with {DAYS_OF_WEEK}
    def day_of_week_id(day)
      if day.respond_to?('to_i') && day.to_i.between?(1, 7)
        return (day.to_i + 1) % 7
      end
      ary_elem_id(DAYS_OF_WEEK, day.capitalize, 'day of week')
    end
  end
end
