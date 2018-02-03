
module MaxCube
  class MessageReceiver < MessageHandler
    private

    module MessageH
      LENGTHS = [10, 6, 4].freeze
      # lengths = [10, 6, 4, 8, 8, 2, 2, 6, 4, 2, 4]
      KEYS = %i[
        serial_number
        rf_address
        firmware_version
      ].freeze
      # unknown
      # http_id
      # duty_cycle
      # free_memory_slots
      # cube_date
      # cube_time
      # state_cube_time
      # ntp_counter
    end

    # Hello message
    def parse_h(body)
      values = body.split(',')
      check_msg_part_lengths(MessageH::LENGTHS, *values)
      hex_to_i_check('firmware version', values[2])
      MessageH::KEYS.zip(values).to_h
    end
  end
end
