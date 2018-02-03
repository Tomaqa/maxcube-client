
module MaxCube
  class MessageReceiver < MessageHandler
    private

    # Metadata message
    def parse_m(body)
      index, count, enc_data = body.split(',')
      lengths = [2, 2]
      check_msg_part_lengths(lengths, index, count)
      index, count = hex_to_i_check('message index, count',
                                    index, count)
      unless index < count
        raise InvalidMessageBody
          .new(@msg_type,
               "index >= count: #{index} >= #{count}")
      end

      unless enc_data
        raise InvalidMessageBody
          .new(@msg_type, 'message data is missing')
      end
      @io = StringIO.new(decode(enc_data), 'rb')

      begin
        hash = {
          index: index, count: count,
          unknown: read(2),
          rooms: [], devices: [],
        }
      rescue IOError
        raise InvalidMessageBody
          .new(@msg_type,
               'unexpected EOF reached at head of decoded message data')
      end

      # Rooms
      begin
        rooms_count = read(1, 'C')
        hash[:rooms_count] = rooms_count
        rooms_count.times do
          room_id = read(1, 'C')
          room_name_length = read(1, 'C')
          room = {
            id: room_id,
            name_length: room_name_length,
            name: read(room_name_length),
            rf_address: read(3)
          }

          # hash[:rooms][room_id] = room
          hash[:rooms] << room
        end
      rescue IOError
        raise InvalidMessageBody
          .new(@msg_type,
               'unexpected EOF reached at rooms data part' \
               ' of decoded message data')
      end

      # Devices
      begin
        devices_count = read(1, 'C')
        hash[:devices_count] = devices_count
        devices_count.times do
          device = {
            type: read(1, 'C'),
            rf_address: read(3),
            serial_number: read(10),
          }
          device_name_length = read(1, 'C')
          device.merge!(
            name_length: device_name_length,
            name: read(device_name_length),
            room_id: read(1, 'C'),
          )

          hash[:devices] << device
        end
      rescue IOError
        raise InvalidMessageBody
          .new(@msg_type,
               'unexpected EOF reached at devices data part' \
               ' of decoded message data')
      end

      hash
    end
  end
end
