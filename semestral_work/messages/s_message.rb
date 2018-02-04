
module MaxCube
  class MessageReceiver < MessageHandler
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
end
