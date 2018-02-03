
module MaxCube
  class MessageReceiver < MessageHandler
    private

    module MessageL
      LENGTHS = [6, 11, 12].freeze
    end

    def parse_l_submsg_1
      @length = read(1, 'C')
      unless MessageL::LENGTHS.include?(@length)
        raise InvalidMessageBody
          .new(@msg_type,
               "invalid length of submessage (#{@length}):" \
               " should be in #{MessageL::LENGTHS}")
      end
      subhash = {
        length: @length,
        rf_address: read(3),
        unknown: read(1),
      }
      flags = read(2, 'n')
      @mode = DEVICE_MODE[flags & 0x3]
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
        .new(@msg_type,
             'unexpected EOF reached at submessage 1st part')
    end

    def parse_l_submsg_2(subhash)
      subhash[:valve_position] = read(1, 'C')

      temperature = read(1, 'C')
      # This bit may be used later
      temperature_msb = temperature >> 7
      subhash[:temperature] = (temperature & 0x3f).to_f / 2

      date_until = read(2, 'n')
      year = (date_until & 0x1f) + 2000
      month = ((date_until & 0x40) >> 6) | ((date_until & 0xe000) >> 12)
      day = (date_until & 0x1f00) >> 8
      time_until = read(1, 'C')
      hour = time_until / 2
      minute = (time_until % 2) * 30
      # Sometimes when device is in 'auto' mode,
      # this field can contain 'actual_temperature' instead
      # (but never if it is already contained in next byte)
      begin
        datetime_until = DateTime.new(year, month, day, hour, minute)
        subhash[:datetime_until] = datetime_until
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

    def parse_l_submsg_3(subhash, temperature_msb)
      subhash[:actual_temperature] = ((temperature_msb << 8) |
                                      read(1, 'C')).to_f / 10
    rescue IOError
      raise InvalidMessageBody
        .new(@msg_type,
             'unexpected EOF reached at submessage 3rd part')
    end

    # Device list message
    def parse_l(body)
      @io = StringIO.new(decode(body), 'rb')

      hash = { devices: [] }
      until @io.eof?
        subhash = parse_l_submsg_1

        temperature_msb = parse_l_submsg_2(subhash) if @length > 6
        parse_l_submsg_3(subhash, temperature_msb) if @length > 11

        hash[:devices] << subhash
      end # until

      hash
    end
  end
end
