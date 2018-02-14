
module MaxCube
  module Messages
    module TCP
      class Parser
        module MessageS
          private

          LENGTHS = [2, 1, 2].freeze
          KEYS = %i[
            duty_cycle
            command_processed
            free_memory_slots
          ].freeze

          # Send command message (response)
          def parse_tcp_s(body)
            values = body.split(',')
            check_msg_part_lengths(MessageS::LENGTHS, *values)
            values = to_ints(16, 'duty cycle, command result,' \
                                 ' free memory slots', *values)
            values[1] = values[1].zero?
            MessageS::KEYS.zip(values).to_h
          end
        end
      end

      class Serializer
        module MessageS
          private

          KEYS = %i[command].freeze
          OPT_KEYS = %i[
            unknown
            rf_flags
            rf_address_from rf_address_to rf_address rf_address_range

            room_id mode temperature datetime_until
            room_id day telegram_set program

            room_id comfort_temperature eco_temperature
            max_setpoint_temperature min_setpoint_temperature
            temperature_offset window_open_temperature window_open_duration

            room_id valve_opening boost_duration
            decalcification_day decalcification_hour
            max_valve_setting valve_offset

            room_id partner_rf_address partner_type
            room_id
            room_id display_temperature
          ].freeze

          COMMANDS = {
            set_temperature_mode: 0x40,
            set_program: 0x10,
            set_temperature: 0x11,
            config_valve: 0x12,
            add_link_partner: 0x20,
            remove_link_partner: 0x21,
            set_group_address: 0x22,
            unset_group_address: 0x23,
            display_temperature: 0x82,
          }.freeze

          DEFAULT_RF_FLAGS = {
            set_temperature_mode: 0x4,
            set_program: 0x4,
            set_temperature: 0x0,
            config_valve: 0x4,
            add_link_partner: 0x0,
            remove_link_partner: 0x0,
            set_group_address: 0x0,
            unset_group_address: 0x0,
            display_temperature: 0x0,
          }.freeze

          # Message to send command to Cube
          def serialize_tcp_s(hash)
            @io = StringIO.new('', 'wb')

            cmd = serialize_tcp_s_head(hash)
            send('serialize_tcp_s_' << cmd.to_s, hash)

            encode(@io.string)
          end

          ########################

          def serialize_tcp_s_head_rf_address(hash)
            rf_address_from = if hash.key?(:rf_address_from)
                                hash[:rf_address_from]
                              elsif hash.key?(:rf_address_range)
                                hash[:rf_address_range].min
                              else
                                0
                              end
            rf_address_to = if hash.key?(:rf_address_to)
                              hash[:rf_address_to]
                            elsif hash.key?(:rf_address_range)
                              hash[:rf_address_range].max
                            else
                              hash[:rf_address]
                            end
            to_ints(0, 'RF address range', rf_address_from, rf_address_to)
          end

          def serialize_tcp_s_head(hash)
            command = hash[:command].to_sym
            command_id = MessageS::COMMANDS[command]
            unless command_id
              raise InvalidMessageBody
                .new(@msg_type, "unknown command symbol: #{command}")
            end

            rf_flags = if hash.key?(:rf_flags)
                         to_int(0, 'RF flags', hash[:rf_flags])
                       else
                         MessageS::DEFAULT_RF_FLAGS[command]
                       end

            rf_address_from, rf_address_to =
              serialize_tcp_s_head_rf_address(hash)

            unknown = hash.key?(:unknown) ? hash[:unknown] : "\x00"
            write(serialize(unknown, rf_flags, command_id, esize: 1) <<
                  serialize(rf_address_from, rf_address_to, esize: 3))

            command
          end

          def serialize_tcp_s_set_temperature_mode(hash)
            @mode = hash[:mode].to_sym
            temp_mode = (to_float('temperature', hash[:temperature]) * 2).to_i |
                        device_mode_id(@mode) << 6
            write(to_int(0, 'room ID', hash[:room_id]), temp_mode, esize: 1)

            return unless @mode == :vacation

            datetime_until = to_datetime('datetime until',
                                         hash[:datetime_until])

            year = datetime_until.year - 2000
            month = datetime_until.month
            day = datetime_until.day
            date_until = year | (month & 1) << 7 |
                         day << 8 | (month & 0xe) << 12

            hours = datetime_until.hour << 1
            minutes = datetime_until.min < 30 ? 0 : 1
            time_until = hours | minutes

            write(serialize(date_until, esize: 2) <<
                  serialize(time_until, esize: 1))
          end

          def serialize_tcp_s_set_program(hash)
            day_of_week = day_of_week_id(hash[:day])
            day_of_week |= 0x8 if hash[:telegram_set]
            write(to_int(0, 'room ID', hash[:room_id]), day_of_week, esize: 1)

            hash[:program].each do |prog|
              temp_time =
                (to_float('temperature', prog[:temperature]) * 2).to_i << 9 |
                (to_int(0, 'hours until', prog[:hours_until]) * 60 +
                 to_int(0, 'minutes until', prog[:minutes_until])) / 5
              write(temp_time, esize: 2)
            end
          end

          def serialize_tcp_s_set_temperature(hash)
            keys = %i[comfort_temperature eco_temperature
                      max_setpoint_temperature min_setpoint_temperature
                      temperature_offset window_open_temperature].freeze
            temperatures = hash.select { |k| keys.include?(k) }
                               .map { |k, v| to_float(k, v) * 2 }
            temperatures[-2] += 7

            open_duration = to_int(0, 'window open duration',
                                   hash[:window_open_duration]) / 5
            write(to_int(0, 'room ID', hash[:room_id]),
                  *temperatures.map(&:to_i), open_duration, esize: 1)
          end

          def serialize_tcp_s_config_valve(hash)
            boost_duration =
              [7, to_int(0, 'boost duration', hash[:boost_duration]) / 5].min
            valve_opening = to_float('valve opening', hash[:valve_opening])
                            .round / 5
            boost = boost_duration << 5 | valve_opening

            decalcification_day = day_of_week_id(hash[:decalcification_day])
            decalcification = decalcification_day << 5 |
                              to_int(0, 'decalcification hour',
                                     hash[:decalcification_hour])

            percent = %i[max_valve_setting valve_offset]
                      .map { |k| (to_float(k, hash[k]) * 2.55).round }

            write(to_int(0, 'room ID', hash[:room_id]),
                  boost, decalcification, *percent, esize: 1)
          end

          def serialize_tcp_s_link_partner(hash)
            partner_type = device_type_id(hash[:partner_type])
            write(serialize(to_int(0, 'room ID', hash[:room_id]), esize: 1) <<
                  serialize(to_int(0, 'partner RF address',
                                   hash[:partner_rf_address]), esize: 3) <<
                  serialize(partner_type, esize: 1))
          end

          def serialize_tcp_s_add_link_partner(hash)
            serialize_tcp_s_link_partner(hash)
          end

          def serialize_tcp_s_remove_link_partner(hash)
            serialize_tcp_s_link_partner(hash)
          end

          def serialize_tcp_s_group_address(hash)
            write(0, to_int(0, 'room ID', hash[:room_id]), esize: 1)
          end

          def serialize_tcp_s_set_group_address(hash)
            serialize_tcp_s_group_address(hash)
          end

          def serialize_tcp_s_unset_group_address(hash)
            serialize_tcp_s_group_address(hash)
          end

          # Works only on wall thermostats
          def serialize_tcp_s_display_temperature(hash)
            display_settings = Hash.new(0)
                                   .merge!(measured: 4, configured: 0)
                                   .freeze
            display = display_settings[hash.fetch(:display_temperature, 'x')
                                           .to_sym]
            write(to_int(0, 'room ID', hash[:room_id]), display, esize: 1)
          end
        end
      end
    end
  end
end
