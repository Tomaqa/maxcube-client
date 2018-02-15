
module MaxCube
  module Messages
    module TCP
      class Parser
        # Device list message.
        module MessageL
          private

          LENGTHS = [6, 11, 12].freeze

          # Mandatory hash keys.
          KEYS = %i[devices].freeze

          def parse_tcp_l(body)
            @io = StringIO.new(decode(body), 'rb')

            hash = { devices: [] }
            until @io.eof?
              subhash = parse_tcp_l_submsg_1

              temperature_msb = parse_tcp_l_submsg_2(subhash) if @length > 6
              parse_tcp_l_submsg_3(subhash, temperature_msb) if @length > 11

              hash[:devices] << subhash
            end

            hash
          end

          ########################

          def parse_tcp_l_submsg_1
            @length = read(1, true)
            unless LENGTHS.include?(@length)
              raise InvalidMessageBody
                .new(@msg_type, "invalid length of submessage (#{@length}):" \
                                " should be in #{LENGTHS}")
            end
            subhash = {
              length: @length,
              rf_address: read(3, true),
              unknown: read(1),
            }
            flags = read(2, true)
            @mode = device_mode(flags & 0x3)
            subhash[:flags] = {
              value: flags,
              mode: @mode,
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

            subhash
          rescue IOError
            raise InvalidMessageBody
              .new(@msg_type, 'unexpected EOF reached at submessage 1st part')
          end

          def parse_tcp_l_submsg_2(subhash)
            subhash[:valve_opening] = read(1, true)

            temperature = read(1, true)
            # This bit may be used later
            temperature_msb = temperature >> 7
            subhash[:temperature] = (temperature & 0x3f).to_f / 2

            date_until = read(2, true)
            year = (date_until & 0x1f) + 2000
            month = ((date_until & 0x80) >> 7) | ((date_until & 0xe000) >> 12)
            day = (date_until & 0x1f00) >> 8

            time_until = read(1, true)
            hours = time_until / 2
            minutes = (time_until % 2) * 30
            # Sometimes when device is in 'auto' mode,
            # this field can contain 'actual_temperature' instead
            # (but never if it is already contained in next byte)
            # !It seems that 'date' is used for 'vacation' mode,
            # but it is not sure ...
            begin
              subhash[:datetime_until] = Time.new(year, month, day,
                                                  hours, minutes)
            rescue ArgumentError
              if @mode != :auto || @length > 11
                raise InvalidMessageBody
                  .new(@msg_type, "unrecognized message part: #{date_until}" \
                                 " (it does not seem to be 'date until'" \
                                 " nor 'actual temperature')")
              end
              subhash[:actual_temperature] = date_until.to_f / 10
            end

            temperature_msb
          rescue IOError
            raise InvalidMessageBody
              .new(@msg_type,
                   'unexpected EOF reached at submessage 2nd part')
          end

          def parse_tcp_l_submsg_3(subhash, temperature_msb)
            subhash[:actual_temperature] = ((temperature_msb << 8) |
                                            read(1, true)).to_f / 10
          rescue IOError
            raise InvalidMessageBody
              .new(@msg_type,
                   'unexpected EOF reached at submessage 3rd part')
          end
        end
      end

      class Serializer
        # Command to resend device list (L).
        # Does not contain any data.
        module MessageL
          private

          def serialize_tcp_l(_hash)
            ''
          end
        end
      end
    end
  end
end
