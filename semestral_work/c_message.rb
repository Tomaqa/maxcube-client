
module MaxCube
  class MessageReceiver < MessageHandler
    private

    # Configuration message
    def parse_c(body)
      addr, enc_data = body.split(',')
      check_msg_part_lengths([6], addr)
      hex_to_i_check('device address', addr)
      @io = StringIO.new(decode(enc_data), 'rb')

      hash = recv_msg_c_head(addr)
      device_type = hash[:device_type]

      begin
        case device_type
        when :cube
          p 18 + @io.size - @io.pos
          p @io.string
          {
            portal_enabled: !read(1, 'C').zero?,
            unknown1: read(12, 'C'),
            pushbutton_up_config: read(1),
            unknown2: read(33),
            pushbutton_down_config: read(1),
            unknown3: read(22),
            portal_url: read(128),
            timezone_winter: read(6),
            timezone_winter_month: read(1),
            timezone_winter_weekday: read(1),
            timezone_winter_offset: read(4),
            timezone_daylight: read(6),
            timezone_daylight_month: read(1),
            timezone_daylight_weekday: read(1),
            timezone_daylight_offset: read(4),
          }
        when :radiator_thermostat, :radiator_thermostat_plus
          subhash = {
            comfort_temperature: read(1, 'C').to_f / 2,
            eco_temperature: read(1, 'C').to_f / 2,
            max_setpoint_temperature: read(1, 'C').to_f / 2,
            min_setpoint_temperature: read(1, 'C').to_f / 2,
            temperature_offset: read(1, 'C').to_f / 2 - 3.5,
            window_open_temperature: read(1, 'C').to_f / 2,
            window_open_duration: read(1, 'C') * 5,
          }

          boost = read(1, 'C')
          boost_duration = ((boost & 0xe0) >> 5) * 5
          boost_duration = 60 if boost_duration > 30
          decalcification = read(1, 'C')
          subhash.merge!(
            boost_duration: boost_duration,
            valve_opening: (boost & 0x1f) * 5,
            day_of_week: DAYS_OF_WEEK[(decalcification & 0xe0) >> 5],
            hour: decalcification & 0x1f,
            max_valve_setting: read(1, 'C') * (100.0 / 255),
            valve_offset: read(1, 'C') * (100.0 / 255),
          )

          program = DAYS_OF_WEEK.zip([]).to_h
          program.each_key do |day|
            setpoints = []
            13.times do
              setpoint = read(2, 'n')
              temperature = ((setpoint & 0xfe00) >> 9).to_f / 2
              time_until = (setpoint & 0x01ff) * 5
              setpoints << {
                temperature: temperature,
                hours_until: time_until / 60,
                minutes_until: time_until % 60,
              }
            end
            program[day] = setpoints
          end
          subhash[:weekly_program] = program

          subhash
        when :wall_thermostat
          subhash[:unknown] = read(3)

          subhash
        end.merge(hash)
      end
    rescue IOError
      raise InvalidMessageBody
        .new(@msg_type,
             'unexpected EOF reached in decoded message data of ' \
             "'#{device_type.to_s.split('_').map(&:capitalize).join(' ')}'" \
             ' device type')
    end

    def recv_msg_c_head(addr)
      @length = read(1, 'C')
      rf_address = read(3)
      device_type_id = read(1, 'C')
      device_type = DEVICE_TYPE[device_type_id]
      unless device_type
        raise InvalidMessageBody
          .new(@msg_type, "unrecognized device type id: #{device_type_id}")
      end
      # Fields 'room_id' and 'firmware_version' have different meaning
      # for 'cube' type
      {
        address: addr,
        length: @length,
        rf_address: rf_address,
        device_type: device_type,
        _room_id: read(1, 'C'),
        _firmware_version: read(1, 'C'),
        test_result: read(1, 'C'),
        serial_number: read(10),
      }
    rescue IOError
      raise InvalidMessageBody
        .new(@msg_type,
             'unexpected EOF reached at head of decoded message data')
    end
  end
end
