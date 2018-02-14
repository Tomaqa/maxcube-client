
module MaxCube
  module Messages
    module TCP
      class Parser
        module MessageH
          private

          LENGTHS = [10, 6, 4, 8, 8, 2, 2, 6, 4, 2, 4].freeze
          KEYS = %i[
            serial_number
            rf_address
            firmware_version
            unknown
            http_id
            duty_cycle
            free_memory_slots
            cube_datetime
            state_cube_time
            ntp_counter
          ].freeze

          # Hello message
          def parse_tcp_h(body)
            values = body.split(',')
            check_msg_part_lengths(MessageH::LENGTHS, *values)
            values[1], _, values[4], values[5], values[6], _, _,
              values[9], values[10] =
              to_ints(16, 'RF address, ' \
                          'firmware version, ' \
                          'HTTP connection ID, ' \
                          'duty cycle, ' \
                          'free memory slots, ' \
                          'Cube date, ' \
                          'Cube time, ' \
                          'state Cube time (clock set), ' \
                          'NTP counter',
                      values[1], values[2], values[4], values[5], values[6],
                      values[7], values[8], values[9], values[10])

            parse_tcp_h_cube_datetime(values)

            MessageH::KEYS.zip(values).to_h
          end

          ########################

          def parse_tcp_h_cube_datetime(values)
            date, time = values[7..8]
            year = 2000 + date[0..1].to_i(16)

            month = date[2..3].to_i(16)
            day = date[4..5].to_i(16)
            hours = time[0..1].to_i(16)
            minutes = time[2..3].to_i(16)

            values[7] = DateTime.new(year, month, day, hours, minutes)
            values.delete_at(8)
          rescue ArgumentError
            raise InvalidMessageBody
              .new(@msg_type, 'invalid datetime format (YYMMDD HHMM): ' \
                              "#{date} #{time} " \
                              "-> #{year}-#{month}-#{day} #{hours}:#{minutes}")
          end
        end
      end
    end
  end
end
