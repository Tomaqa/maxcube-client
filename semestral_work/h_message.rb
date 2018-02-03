
module MaxCube
  class MessageReceiver < MessageHandler
    private

    # Hello message
    def parse_h(body)
      values = body.split(',')
      # lengths = [10, 6, 4, 8, 8, 2, 2, 6, 4, 2, 4]
      lengths = [10, 6, 4]
      check_msg_part_lengths(lengths, *values)
      values[2] = hex_to_i_check('firmware version', values[2])[0]
      keys = %i[
        serial_number
        rf_address
        firmware_version
      ]
      # unknown
      # http_id
      # duty_cycle
      # free_memory_slots
      # cube_date
      # cube_time
      # state_cube_time
      # ntp_counter
      keys.zip(values).to_h
    end
  end
end
