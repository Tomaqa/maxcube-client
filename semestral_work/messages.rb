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

    def check_msg_part_lengths(msg_type, lengths, *args)
      return if valid_msg_part_lengths(lengths, *args)
      raise InvalidMessageBody
        .new(msg_type,
             "invalid lengths of message parts #{args}" \
             " (lengths should be: #{lengths})")
    end

    # Convert string of characters (not binary data!) to hex number
    # For binary data use #String.unpack
    def hex_to_i_check(msg_type, info, *args)
      if args.all? { |x| x && !x[/\H/] && !x[/^$/] }
        return args.map { |x| x.to_i(16) }
      end
      raise InvalidMessageBody
        .new(msg_type,
             "invalid hex format of message parts #{args}" \
             " (#{info})")
    end

    def check_msg_min_data_length(msg_type, min_length, length, info)
      return unless length < min_length
      raise InvalidMessageBody
        .new(msg_type,
             "#{info} - remaining data length is insufficient" \
             " (#{length} < #{min_length})")
    end

    def encode(data)
      Base64.strict_encode64(data)
    end

    def decode(data)
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
      return if msg_type
      raise InvalidMessageType.new(msg_type)
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
      msg_type, body = msg.split(':')
      body ||= ''
      send("recv_msg_#{msg_type.downcase}", msg_type, body)
        .merge(type: msg_type)
    end

    private

    # Acknowledgement message to previous reset
    # Ignore all contents of the message
    def recv_msg_a(_msg_type, _body)
      {}
    end

    # Hello message
    def recv_msg_h(msg_type, body)
      values = body.split(',')
      # lengths = [10, 6, 4, 8, 8, 2, 2, 6, 4, 2, 4]
      lengths = [10, 6, 4]
      check_msg_part_lengths(msg_type, lengths, *values)
      values[2] = hex_to_i_check(msg_type, 'firmware version', values[2])[0]
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

    # Device list message
    def recv_msg_l(msg_type, body)
      data_io = StringIO.new(decode(body))

      hash = { devices: [] }
      until data_io.eof?
        check_msg_min_data_length(msg_type,
                                  6,
                                  data_io.size - data_io.pos,
                                  'submessage')
        length = data_io.read(1).unpack1('C')

        subhash = {
          length: length,
          rf_address: data_io.read(3),
          unknown: data_io.read(1),
        }
        flags = data_io.read(2).unpack1('n')
        mode = %i[auto manual vacation boost][flags & 0x3]
        subhash[:flags] = {
          value: flags,
          mode: mode,
          dst_setting_active: !((flags & 0x8) >> 3).zero?,
          gateway_known: !((flags & 0x10) >> 4).zero?,
          panel_locked: !((flags & 0x20) >> 5).zero?,
          link_error: !((flags & 0x40) >> 6).zero?,
          low_battery: !((flags & 0x80) >> 7).zero?,
          status_initialized: !((flags & 0x200) >> 9).zero?,
          is_answer: !((flags & 0x400) >> 10).zero?,
          error: !((flags & 0x800) >> 11).zero?,
          valid_info: !((flags & 0x1000) >> 12).zero?,
        }

        if length > 6
          subhash[:valve_position] = data_io.read(1).unpack1('C')

          temperature = data_io.read(1).unpack1('C')
          # This bit may be used later
          temperature_msb = temperature >> 7
          subhash[:temperature] = (temperature & 0x3f).to_f / 2

          date_until = data_io.read(2).unpack1('n')
          year = (date_until & 0x1f) + 2000
          month = ((date_until & 0x40) >> 6) | ((date_until & 0xe000) >> 12)
          day = (date_until & 0x1f00) >> 8
          time_until = data_io.read(1).unpack1('C')
          hour = time_until / 2
          minute = (time_until % 2) * 30
          begin
            datetime_until = DateTime.new(year, month, day, hour, minute)
            subhash[:datetime_until] = datetime_until
          rescue ArgumentError
            if mode != :auto || length > 11
              raise InvalidMessageBody
                .new(msg_type, "unrecognized message part: #{date_until}" \
                               " (it does not seem to be 'date until'" \
                               " nor 'actual temperature')")
            end
            subhash[:actual_temperature] = date_until.to_f / 10
          end
        end

        if length > 11
          subhash[:actual_temperature] = ((temperature_msb << 8) |
                                       data_io.read(1).unpack1('C')).to_f / 10
        end

        hash[:devices] << subhash
      end # until

      hash
    end

    # Metadata message
    def recv_msg_m(msg_type, body)
      index, count, enc_data = body.split(',')
      lengths = [2, 2]
      check_msg_part_lengths(msg_type, lengths, index, count)
      index, count = hex_to_i_check(msg_type,
                                    'message index, count',
                                    index, count)
      unless index < count
        raise InvalidMessageBody
          .new(msg_type,
               "index >= count: #{index} >= #{count}")
      end

      unless enc_data
        raise InvalidMessageBody
          .new(msg_type, 'message data is missing')
      end
      data_io = StringIO.new(decode(enc_data))
      check_msg_min_data_length(msg_type, 4, data_io.size, 'rooms/devices')

      hash = {
        index: index, count: count,
        unknown: data_io.read(2),
        rooms: [], devices: [],
      }

      # Rooms
      rooms_count = data_io.read(1).unpack1('C')
      check_msg_min_data_length(msg_type,
                                rooms_count * 5,
                                data_io.size - data_io.pos,
                                'rooms')
      hash[:rooms_count] = rooms_count
      rooms_count.times do
        room_id = data_io.read(1).unpack1('C')
        room_name_length = data_io.read(1).unpack1('C')
        check_msg_min_data_length(msg_type,
                                  room_name_length + 3,
                                  data_io.size - data_io.pos,
                                  'room')
        room = {
          id: room_id,
          name_length: room_name_length,
          name: data_io.read(room_name_length),
          rf_address: data_io.read(3),
        }

        # hash[:rooms][room_id] = room
        hash[:rooms] << room
      end

      # Devices
      check_msg_min_data_length(msg_type, 1,
                                data_io.size - data_io.pos,
                                'devices')
      devices_count = data_io.read(1).unpack1('C')
      devices_min_length = devices_count * 16
      check_msg_min_data_length(msg_type,
                                devices_min_length,
                                data_io.size - data_io.pos,
                                'devices')
      hash[:devices_count] = devices_count
      devices_count.times do
        device = {
          type: data_io.read(1).unpack1('C'),
          rf_address: data_io.read(3),
          serial_number: data_io.read(10),
        }
        device_name_length = data_io.read(1).unpack1('C')
        check_msg_min_data_length(msg_type,
                                  device_name_length + 1,
                                  data_io.size - data_io.pos,
                                  'device')
        device.merge!(
          name_length: device_name_length,
          name: data_io.read(device_name_length),
          room_id: data_io.read(1).unpack1('C'),
        )

        hash[:devices] << device
      end

      hash
    end
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

