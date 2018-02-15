
module MaxCube
  module Messages
    module TCP
      class Parser
        # Metadata message.
        module MessageM
          private

          LENGTHS = [2, 2].freeze

          # Mandatory hash keys.
          KEYS = %i[index count unknown1 unknown2
                    rooms_count rooms devices_count devices].freeze

          def parse_tcp_m(body)
            index, count, enc_data = parse_tcp_m_split(body)

            @io = StringIO.new(decode(enc_data), 'rb')

            hash = { index: index, count: count, unknown1: read(2), }
            parse_tcp_m_rooms(hash)
            parse_tcp_m_devices(hash)
            hash[:unknown2] = read(1)

            hash
          rescue IOError
            raise InvalidMessageBody
              .new(@msg_type,
                   'unexpected EOF reached at unknown parts' \
                   ' of decoded message data')
          end

          ########################

          def parse_tcp_m_split(body)
            index, count, enc_data = body.split(',')
            check_msg_part_lengths(LENGTHS, index, count)
            index, count = to_ints(16, 'message index, count',
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

          def parse_tcp_m_rooms(hash)
            rooms_count = read(1, true)
            hash[:rooms_count] = rooms_count
            hash[:rooms] = []
            rooms_count.times do
              room_id = read(1, true)
              room_name_length = read(1, true)
              room = {
                id: room_id,
                name_length: room_name_length,
                name: read(room_name_length),
                rf_address: read(3, true)
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

          def parse_tcp_m_devices(hash)
            devices_count = read(1, true)
            hash[:devices_count] = devices_count
            hash[:devices] = []
            devices_count.times do
              device = {
                type: device_type(read(1, true)),
                rf_address: read(3, true),
                serial_number: read(10),
              }
              device_name_length = read(1, true)
              device.merge!(
                name_length: device_name_length,
                name: read(device_name_length),
                room_id: read(1, true),
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
      end

      class Serializer
        # Serializes metadata for Cube.
        # Message body has the same format as response (M)
        # -> reverse operations.
        # Cube does not check data format,
        # so things could break if invalid data is sent.
        #
        # ! I couldn't verify the assumption that bodies should be the same.
        module MessageM
          private

          # Mandatory hash keys.
          KEYS = %i[rooms_count rooms devices_count devices].freeze
          # Optional hash keys.
          OPT_KEYS = %i[index unknown1 unknown2].freeze

          def serialize_tcp_m(hash)
            index = hash.key?(:index) ? to_int(0, 'index', hash[:index]) : 0
            head = format('%02x,', index)

            @io = StringIO.new('', 'wb')
            write(hash.key?(:unknown1) ? hash[:unknown1] : "\x00\x00")

            serialize_tcp_m_rooms(hash)
            serialize_tcp_m_devices(hash)
            write(hash.key?(:unknown2) ? hash[:unknown2] : "\x00")

            head.b << encode(@io.string)
          end

          ########################

          def serialize_tcp_m_rooms(hash)
            write(to_int(0, 'rooms count', hash[:rooms_count]), esize: 1)
            hash[:rooms].each do |room|
              name = room[:name]
              if room.key?(:name_length)
                name_length = to_int(0, 'name length', room[:name_length])
                unless name_length == name.length
                  raise InvalidMessageBody
                    .new(@msg_type, 'room name length and length of name' \
                         " mismatch: #{name_length} != #{name.length}")
                end
              else
                name_length = name.length
              end

              id, rf_address = to_ints(0, 'room id, RF address',
                                       room[:id], room[:rf_address])
              write(serialize(id, name_length, name, esize: 1) <<
                    serialize(rf_address, esize: 3))
            end
          end

          def serialize_tcp_m_devices(hash)
            write(to_int(0, 'devices count', hash[:devices_count]), esize: 1)
            hash[:devices].each do |device|
              name = device[:name]
              if device.key?(:name_length)
                name_length = to_int(0, 'name length', device[:name_length])
                unless name_length == name.length
                  raise InvalidMessageBody
                    .new(@msg_type, 'device name length and length of name' \
                         " mismatch: #{name_length} != #{name.length}")
                end
              else
                name_length = name.length
              end

              rf_address, room_id =
                to_ints(0, 'device RF address, room ID',
                        device[:rf_address], device[:room_id])
              write(serialize(device_type_id(device[:type]), esize: 1) <<
                    serialize(rf_address, esize: 3) <<
                    serialize(device[:serial_number],
                              name_length, name, room_id, esize: 1))
            end
          end
        end
      end
    end
  end
end
