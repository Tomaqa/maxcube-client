
module MaxCube
  class MessageParser < MessageHandler
    private

    module MessageC
      LENGTHS = [6].freeze
    end

    # Configuration message
    def parse_c(body)
      addr, enc_data = parse_c_split(body)

      @io = StringIO.new(decode(enc_data), 'rb')

      hash = parse_c_head(addr)
      parse_c_device_type(hash)

      hash
    end

    ########################

    def parse_c_split(body)
      addr, enc_data = body.split(',')
      check_msg_part_lengths(MessageC::LENGTHS, addr)
      to_ints(16, 'device address', addr)
      [addr, enc_data]
    end

    def parse_c_head(addr)
      @length = read(1, true)
      # 'rf_address' should correspond with 'addr',
      # but it is not checked (yet)
      rf_address = read(3, true)
      device_type = device_type(read(1, true))
      hash = {
        address: addr,
        length: @length,
        rf_address: rf_address,
        device_type: device_type,
      }

      if device_type == :cube
        # For 'cube' type, both fiels seem to be combined
        # into 'firmware_version' string
        room_id__fw_v = read(2, 'H*')
        hash[:firmware_version] = room_id__fw_v[2..3] + room_id__fw_v[0..1]
      else
        # For other types, both 'room_id' and 'firmware_version'
        # are unpacked as numbers
        # How should be 'firmware_version' interpreted ?
        hash[:room_id] = read(1, true)
        hash[:_firmware_version] = read(1, true)
      end

      hash.merge!(
        test_result: read(1, true),
        serial_number: read(10),
      )
    rescue IOError
      raise InvalidMessageBody
        .new(@msg_type,
             'unexpected EOF reached at head of decoded message data')
    end

    def parse_c_cube_button_mode_temp(value, base)
      (value - base).to_f / 2 + 4.5
    end

    def parse_c_cube_button_mode(hash, up, down)
      { 'up' => up, 'down' => down }.each do |k, v|
        mode_key = "button_#{k}_mode".to_sym
        case v
        when 0x00
          hash[mode_key] = :auto
        when 0x41
          hash[mode_key] = :eco
        when 0x42
          hash[mode_key] = :comfort
        else
          temp_key = "button_#{k}_temperature".to_sym
          if v.between?(0x09, 0x3d)
            hash[mode_key] = :auto_temp
            hash[temp_key] = parse_c_cube_button_mode_temp(v, 0x09)
          elsif v.between?(0x49, 0x7d)
            hash[mode_key] = :manual
            hash[temp_key] = parse_c_cube_button_mode_temp(v, 0x49)
          else
            hash[mode_key] = :unknown
          end
        end
      end
    end

    def parse_c_cube
      hash = {
        portal_enabled: !read(1, true).zero?,
        unknown1: read(11),
      }

      pushbutton_up_config = read(1, true)
      hash[:unknown2] = read(32)
      pushbutton_down_config = read(1, true)
      parse_c_cube_button_mode(hash,
                               pushbutton_up_config,
                               pushbutton_down_config)

      # ! Exact decoding of time zones is not clear yet
      hash.merge!(
        unknown3: read(21),
        portal_url: read(128),
        # _timezone_winter: read(5),
        # timezone_winter_month: read(1, true),
        # timezone_winter_day: DAYS_OF_WEEK[read(1, true)],
        # timezone_winter_hour: read(1, true),
        # _timezone_winter_offset: read(4),
        # _timezone_daylight: read(5),
        # timezone_daylight_month: read(1, true),
        # timezone_daylight_day: DAYS_OF_WEEK[read(1, true)],
        # timezone_daylight_hour: read(1, true),
        # _timezone_daylight_offset: read(4),
        # unknown4: read(1),
        unknown4: read,
      )
    end

    def parse_c_thermostat_1
      {
        comfort_temperature: read(1, true).to_f / 2,
        eco_temperature: read(1, true).to_f / 2,
        max_setpoint_temperature: read(1, true).to_f / 2,
        min_setpoint_temperature: read(1, true).to_f / 2,
      }
    end

    def parse_c_program(subhash)
      program = DAYS_OF_WEEK.zip([]).to_h
      program.each_key do |day|
        setpoints = []
        13.times do
          setpoint = read(2, true)
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
    end

    def parse_c_radiator
      subhash = parse_c_thermostat_1.merge!(
        temperature_offset: read(1, true).to_f / 2 - 3.5,
        window_open_temperature: read(1, true).to_f / 2,
        window_open_duration: read(1, true) * 5,
      )

      boost = read(1, true)
      boost_duration = ((boost & 0xe0) >> 5) * 5
      boost_duration = 60 if boost_duration > 30

      decalcification = read(1, true)

      subhash.merge!(
        boost_duration: boost_duration,
        valve_opening: (boost & 0x1f) * 5,
        decalcification_day: DAYS_OF_WEEK[(decalcification & 0xe0) >> 5],
        decalcification_hour: decalcification & 0x1f,
        max_valve_setting: read(1, true) * (100.0 / 255),
        valve_offset: read(1, true) * (100.0 / 255),
      )

      parse_c_program(subhash)

      subhash
    end

    def parse_c_wall
      subhash = parse_c_thermostat_1
      parse_c_program(subhash)
      subhash[:unknown] = read(3)

      subhash
    end

    def parse_c_device_type(hash)
      device_type = hash[:device_type]
      hash.merge!(
        case device_type
        when :cube
          parse_c_cube
        when :radiator_thermostat, :radiator_thermostat_plus
          parse_c_radiator
        when :wall_thermostat
          parse_c_wall
        else
          {}
        end
      )
    rescue IOError
      raise InvalidMessageBody
        .new(@msg_type,
             'unexpected EOF reached in decoded message data of ' \
             "'#{device_type.to_s.split('_').map(&:capitalize).join(' ')}'" \
             ' device type')
    end
  end

  class MessageSerializer < MessageHandler
    private

    module MessageC
    end

    # Request for configuration message (C)
    # Does not contain any data
    def serialize_c(_hash)
      ''
    end
  end
end
