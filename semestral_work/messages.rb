require 'base64'
require 'stringio'

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

    class InvalidMessage < RuntimeError; end

    class InvalidMessageEmpty < InvalidMessage
      def initialize(info = 'empty message')
        super
      end
    end

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

    def valid_msg_part_lengths(lengths, *args)
      return false if args.any?(&:nil?) ||
        args.length < lengths.length
      args.each_with_index.all? do |v, i|
        !lengths[i] || v.length == lengths[i]
      end
    end

    def check_msg_part_lengths(msg_type, lengths, *args)
      return if valid_msg_part_lengths(lengths, *args)
      raise InvalidMessageBody.new(msg_type,
        "invalid lengths of message parts #{args} (lengths should be: #{lengths})")
    end

    # Convert string of characters (not binary data!) to hex number
    # For binary data use #String.unpack
    def hex_to_i_check(msg_type, info, *args)
      raise InvalidMessageBody.new(msg_type,
        "invalid hex format of message parts #{args} (#{info})") unless args.all? do |x|
          x && !x[/\H/] && !x[/^$/]
        end
      args.map { |x| x.to_i(16) }
    end

    def check_msg_min_data_length(msg_type, min_length, length, info)
      return unless length < min_length
      raise InvalidMessageBody.new(msg_type, "#{info} - remaining data length is insufficient (#{length} < #{min_length})")
    end

    def encode(data)
      # Base64.encode64(data)
      Base64.strict_encode64(data)
    end

    def decode(data)
      # Base64.decode64(data)
      Base64.strict_decode64(data)
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
    #! Dokumentovat vstup jako String a vyradit type checking
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
      check_msg_part_lengths(msg_type, lengths, *values)
      values[2] = hex_to_i_check(msg_type, 'firmware version', values[2])[0]
      # values[2] = values[2].unpack('N')[0]
      keys = %i[
        serial_number
        rf_address
        firmware_version
      ]
        # unknown
        # http_id
        # duty_cycle
        # free_memory_slots
        # cube_date
        # cube_time
        # state_cube_time
        # ntp_counter
      keys.zip(values).to_h
    end

    # Metadata message
    def recv_msg_m(msg_type, body)
      index, count, enc_data = body.split(',')
      lengths = [2, 2]
      check_msg_part_lengths(msg_type, lengths, index, count)
      index, count = hex_to_i_check(msg_type, 'message index, count', index, count)
      # index, count = [index, count].map { |x| x.unpack('n')[0] }
      raise InvalidMessageBody.new(msg_type, "index >= count: #{index} >= #{count}") unless index < count

      raise InvalidMessageBody.new(msg_type, "message data is missing") unless enc_data
      data_io = StringIO.new(decode(enc_data))
      check_msg_min_data_length(msg_type, 4, data_io.size, 'rooms/devices')
      
      hash = { index: index, count: count }
      # hash[:unknown] = data_io.read(2)
      hash[:unknown] = data_io.read(2).unpack1('Z*')
      # a = hash[:unknown]
      # hash[:unknown] = "V\x02"
      # hash[:unknown] = "V\u0002"
      # p a
      # p hash[:unknown]
      # p a == hash[:unknown]
      # p ''

      # Rooms
      # rooms_count = hex_to_i_check(msg_type, 'rooms count', data_io.read(1))[0]
      rooms_count = data_io.read(1).unpack1('C')
      rooms_min_length = rooms_count * 5
      check_msg_min_data_length(msg_type, rooms_min_length, data_io.size - data_io.pos, 'rooms')
      hash[:rooms_count] = rooms_count
      # hash[:rooms] = {}
      hash[:rooms] = []
      rooms_count.times do
        room = {}
        # room_id = hex_to_i_check(msg_type, 'room ID', data_io.read(1))[0]
        room_id = data_io.read(1).unpack1('C')
        room[:id] = room_id
        # room_name_length = hex_to_i_check(msg_type, 'room name length', data_io.read(1))[0]
        room_name_length = data_io.read(1).unpack1('C')
        check_msg_min_data_length(msg_type, room_name_length + 3, data_io.size - data_io.pos, 'room')
        room[:name_length] = room_name_length
        room[:name] = data_io.read(room_name_length)
        room[:rf_address] = data_io.read(3)

        # hash[:rooms][room_id] = room
        hash[:rooms] << room
      end

      # Devices
      check_msg_min_data_length(msg_type, 1, data_io.size - data_io.pos, 'devices')
      # devices_count = hex_to_i_check(msg_type, 'devices count', data_io.read(1))[0]
      devices_count = data_io.read(1).unpack1('C')
      devices_min_length = devices_count * 16
      check_msg_min_data_length(msg_type, devices_min_length, data_io.size - data_io.pos, 'devices')
      hash[:devices_count] = devices_count
      hash[:devices] = []
      devices_count.times do
        device = {}
        # device[:type] = hex_to_i_check(msg_type, 'device type', data_io.read(1))[0]
        device[:type] = data_io.read(1).unpack1('C')
        device[:rf_address] = data_io.read(3)
        device[:serial_number] = data_io.read(10)
        # device_name_length = hex_to_i_check(msg_type, 'device name length', data_io.read(1))[0]
        device_name_length = data_io.read(1).unpack1('C')
        check_msg_min_data_length(msg_type, device_name_length + 1, data_io.size - data_io.pos, 'device')
        device[:name_length] = device_name_length
        device[:name] = data_io.read(device_name_length)
        # device[:room_id] = hex_to_i_check(msg_type, "device's room ID", data_io.read(1))[0]
        device[:room_id] = data_io.read(1).unpack1('C')

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
