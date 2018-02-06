
module MaxCube
  class MessageParser < MessageHandler
    private

    module MessageM
      LENGTHS = [2, 2].freeze
    end

    # Metadata message
    def parse_m(body)
      index, count, enc_data = parse_m_split(body)

      @io = StringIO.new(decode(enc_data), 'rb')

      hash = { index: index, count: count, unknown1: read(2), }
      parse_m_rooms(hash)
      parse_m_devices(hash)
      hash[:unknown2] = read(1)

      hash
    rescue IOError
      raise InvalidMessageBody
        .new(@msg_type,
             'unexpected EOF reached at unknown parts of decoded message data')
    end

    ########################

    def parse_m_split(body)
      index, count, enc_data = body.split(',')
      check_msg_part_lengths(MessageM::LENGTHS, index, count)
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

      [index, count, enc_data]
    end

    def parse_m_rooms(hash)
      rooms_count = read(1, 'C')
      hash[:rooms_count] = rooms_count
      hash[:rooms] = []
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

    def parse_m_devices(hash)
      devices_count = read(1, 'C')
      hash[:devices_count] = devices_count
      hash[:devices] = []
      devices_count.times do
        device = {
          type: device_type(read(1, 'C')),
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
  end

  class MessageSerializer < MessageHandler
    private

    module MessageM
    end

    # Serialize metadata for Cube
    # Message body has the same format as response (M)
    # -> reverse operations
    # ! I couldn't verify the assumption that bodies should be the same
    # ! Cube does not check data format,
    #   so things could break if invalid data is sent
    def serialize_m(hash)
      index = hash.include?(:index) ? hash[:index] : 0
      head = format('%02x,', index)

      @io = StringIO.new('', 'wb')
      @io.write(hash.include?(:unknown1) ? hash[:unknown1] : "\x00\x00")

      serialize_m_rooms(hash)
      serialize_m_devices(hash)
      @io.write(hash.include?(:unknown2) ? hash[:unknown2] : "\x00")

      head.b << encode(@io.string)
    end

    ########################

    def serialize_m_rooms(hash)
      @io.write([hash[:rooms_count]].pack('C'))
      hash[:rooms].each do |room|
        @io.write([room[:id], room[:name_length]].pack('C2') <<
                  room[:name] <<
                  room[:rf_address])
      end
    end

    def serialize_m_devices(hash)
      @io.write([hash[:devices_count]].pack('C'))
      hash[:devices].each do |device|
        @io.write([device_type_id(device[:type])].pack('C') <<
                  device[:rf_address] <<
                  device[:serial_number] <<
                  [device[:name_length]].pack('C') <<
                  device[:name] <<
                  [device[:room_id]].pack('C'))
      end
    end
  end
end
