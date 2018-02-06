
module MaxCube
  class MessageParser < MessageHandler
    private

    module MessageS
      LENGTHS = [2, 1, 2].freeze
      KEYS = %i[
        duty_cycle
        command_processed
        free_memory_slots
      ].freeze
    end

    # Send command message (response)
    def parse_s(body)
      values = body.split(',')
      check_msg_part_lengths(MessageS::LENGTHS, *values)
      values = hex_to_i_check('duty cycle, command result, free memory slots',
                              *values)
      values[1] = values[1].zero?
      MessageS::KEYS.zip(values).to_h
    end
  end

  class MessageSerializer < MessageHandler
    private

    module MessageS
      COMMANDS = { set_temperature_mode: 0x40,
                   set_program: 0x10,
                   set_temperature: 0x11,
                   config_valve: 0x12, }.freeze
    end

    # Message to send command to Cube
    def serialize_s(hash)
      @io = StringIO.new('', 'wb')

      cmd = serialize_s_head(hash)
      send('serialize_s_' << cmd.to_s, hash)

      encode(@io.string)
    end

    ########################

    def serialize_s_head_rf_address(hash)
      rf_address_from = if hash.include?(:rf_address_from)
                          hash[:rf_address_from]
                        elsif hash.include?(:rf_address_range)
                          hash[:rf_address_range].min
                        else
                          0
                        end
      rf_address_to = if hash.include?(:rf_address_to)
                        hash[:rf_address_to]
                      elsif hash.include?(:rf_address_range)
                        hash[:rf_address_range].max
                      else
                        hash[:rf_address]
                      end
      [rf_address_from, rf_address_to]
    end

    def serialize_s_head(hash)
      rf_flags = hash[:rf_flags]
      command = hash[:command]
      command_id = MessageS::COMMANDS[command]
      unless command_id
        raise InvalidMessageBody
          .new(@msg_type, "unknown command symbol: #{command}")
      end

      rf_address_from, rf_address_to = serialize_s_head_rf_address(hash)

      @io.write(hash[:unknown] <<
                [rf_flags, command_id].pack('C2') <<
                [rf_address_from].pack('N')[1..-1] <<
                [rf_address_to].pack('N')[1..-1])

      command
    end

    def serialize_s_set_temperature_mode(hash)
      @mode = hash[:mode]
      temp_mode = (hash[:temperature] * 2).to_i |
                  device_mode_id(@mode) << 6
      @io.write([hash[:room_id], temp_mode].pack('C2'))

      return unless @mode == :vacation

      datetime_until = hash[:datetime_until]

      year = datetime_until.year - 2000
      month = datetime_until.month
      day = datetime_until.day
      date_until = year | (month & 1) << 7 |
                   day << 8 | (month & 0xe) << 12

      hours = datetime_until.hour << 1
      minutes = datetime_until.min < 30 ? 0 : 1
      time_until = hours | minutes

      @io.write([date_until].pack('n') << [time_until].pack('C'))
    end

    def serialize_s_set_program(hash)
      day_of_week = DAYS_OF_WEEK.index(hash[:day])
      day_of_week |= 0x8 if hash[:telegram_set]
      @io.write([hash[:room_id], day_of_week].pack('C2'))

      hash[:program].each do |p|
        temp_time = (p[:temperature] * 2).to_i << 9
        temp_time |= (p[:hours_until] * 60 + p[:minutes_until]) / 5
        @io.write([temp_time].pack('n'))
      end
    end

    def serialize_s_set_temperature(hash)
      @io.write([hash[:room_id]].pack('C'))

      keys = %i[comfort_temperature eco_temperature
                max_setpoint_temperature min_setpoint_temperature
                temperature_offset window_open_temperature].freeze
      temperatures = hash.select { |k| keys.include?(k) }.map { |_, v| v * 2 }
      temperatures[-2] += 7

      open_duration = hash[:window_open_duration] / 5
      @io.write(temperatures.map(&:to_i).pack('C*') << open_duration)
    end

    def serialize_s_config_valve(hash)
      boost_duration = [hash[:boost_duration] / 5, 7].min
      valve_opening = hash[:valve_opening] / 5
      boost = boost_duration << 5 | valve_opening

      decalcification_day = DAYS_OF_WEEK.index(hash[:decalcification_day])
      decalcification = decalcification_day << 5 | hash[:decalcification_hour]

      @io.write([hash[:room_id], boost, decalcification].pack('C3'))
      @io.write([hash[:max_valve_setting], hash[:valve_offset]]
                  .map { |x| (x * 2.55).round }.pack('C2'))
    end
  end
end
