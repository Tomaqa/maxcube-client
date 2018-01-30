require 'base64'
require 'stringio'

module MaxCube
  # Structure of message:
  # * Starts with single letter followed by ':'
  # * Ends with '\r\n'
  # Example (unencoded):
  # X:message\r\n
  class MessageHandler

    class InvalidMessage < RuntimeError; end

    class InvalidMessageEmpty < InvalidMessage
      def initialize(info = 'empty message')
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

    # Check single message validity, ignoring presence of '\r\n' at the end
    def valid_msg(msg)
      msg =~ /^[[:alpha:]]:[^:]*$/
    end

    def check_msg(msg)
      raise InvalidMessageFormat unless valid_msg(msg)
    end

    def empty_data(raw_data)
      raw_data.empty?
    end

    def check_empty_data(raw_data)
      raise InvalidMessageEmpty if empty_data(raw_data)
    end

    def valid_data_type(raw_data)
      raw_data.is_a?(String)
    end

    def check_data_type(raw_data)
      raise TypeError unless valid_data_type(raw_data)
    end

    private

    def check_data(raw_data)
      check_data_type(raw_data)
      check_empty_data(raw_data)
    end

    def valid_lengths(lengths, *args)
      return false if args.any?(&:nil?) ||
        args.length < lengths.length
      args.each_with_index.all? do |v, i|
        !lengths[i] || v.length == lengths[i]
      end
    end

    def check_lengths(msg_type, lengths, *args)
      return if valid_lengths(lengths, *args)
      raise InvalidMessageBody.new(msg_type,
        "invalid lengths of message parts #{args} (lengths should be: #{lengths})")
    end

    def valid_types(type, *args)
      args.all? { |x| x.is_a?(type) }
    end

    def check_types(msg_type, type, *args)
      return if valid_types(type, *args)
      raise InvalidMessageBody.new(msg_type,
        "invalid types of message parts #{args} (type should be: #{type})")
    end

    def encode(data)
      Base64.encode64(data)
    end

    def decode(data)
      Base64.decode64(data)
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
      msg_type = valid_recv_msg_type(msg)
      raise InvalidMessageType.new(msg_type) unless msg_type
    end

    # Check single message validity, which is already without '\r\n'
    def valid_recv_msg(msg)
      valid_msg(msg) && valid_recv_msg_type(msg)
    end

    def check_recv_msg(msg)
      check_msg(msg)
      check_recv_msg_type(msg)
    end

    # Process set of messages - raw data separated by '\r\n'
    # Returns array of hashes
    def recv_data(raw_data)
      check_data(raw_data)
      raw_data.split("\r\n").map(&method(:recv_msg)).to_a
    end

    # Parse single message already without '\r\n'
    # Separates particular data into hash
    # TODO: how to correctly deal with invalid messages?
    def recv_msg(msg)
      check_recv_msg(msg)
      msg_type, body = msg.split(':')
      body ||= ''
      send("recv_msg_#{msg_type.downcase}", msg_type, body).merge( type: msg_type )
    end

    private

    # Acknowledgement message
    def recv_msg_a(msg_type, body)
      {}
    end

    # Hello message
    def recv_msg_h(msg_type, body)
      values = body.split(',')
      # lengths = [10, 6, 4, 8, 8, 2, 2, 6, 4, 2, 4]
      lengths = [10, 6, 4]
      check_lengths(msg_type, lengths, *values)
      keys = %i[
        serial_number
        rf_address
        firmware_version
        # unknown
        # http_id
        # duty_cycle
        # free_memory_slots
        # cube_date
        # cube_time
        # state_cube_time
        # ntp_counter
      ]
      keys.zip(values).to_h
    end

    # Metadata message
    def recv_msg_m(msg_type, body)
      index, count, enc_data = body.split(',')
      lengths = [2, 2]
      check_lengths(msg_type, lengths, index, count)
      [index, count].map(&:to_i)
      check_types(msg_type, Integer, index, count)

      data_io = StringIO.new(decode(enc_data))
      hash = { index: index, count: count }

      # Rooms
      hash[:rooms_unknown] = data_io.read(2)
      rooms_count = data_io.read(1).to_i
      hash[:rooms_count] = rooms_count
      # hash[:rooms] = {}
      hash[:rooms] = []
      rooms_count.times do
        room = {}
        room_id = data_io.read(1).to_i
        room[:id] = room_id
        room_name_length = data_io.read(1).to_i
        room[:name_length] = room_name_length
        room[:name] = data_io.read(room_name_length)
        room[:rf_address] = data_io.read(3)

        # hash[:rooms][room_id] = room
        hash[:rooms] << room
      end

      # Devices
      devices_count = data_io.read(1).to_i
      hash[:devices_count] = devices_count
      hash[:devices] = []
      devices_count.times do
        device = {}
        device[:type] = data_io.read(1).to_i
        device[:rf_address] = data_io.read(3)
        device[:serial_number] = data_io.read(10)
        device_name_length = data_io.read(1).to_i
        device[:name_length] = device_name_length
        device[:name] = data_io.read(device_name_length)
        device[:room_id] = data_io.read(1).to_i

        hash[:devices] << device
      end

      hash
    end

  end

  class MessageSender < MessageHandler
    MSG_TYPES = %w[u i s m n x g q e d B G J P O V W a r t w l c v f z].freeze
  end
end

# MaxCube::MessageReceiver.new.recv_data('')
# MaxCube::MessageReceiver.new.recv_data(':')
MaxCube::MessageReceiver.new.recv_data('H:')
