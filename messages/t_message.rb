
module MaxCube
  class MessageSerializer < MessageHandler
    private

    module MessageT
      KEYS = %i[count force rf_addresses].freeze
    end

    # Command to delete one or more devices from the Cube
    # Acknowledgement (A) follows
    def serialize_t(hash)
      count = format('%02x', to_int(0, 'count', hash[:count]))
      force = to_bool('force mode', hash[:force]) ? '1' : '0'
      rf_addresses = to_ints(0, 'RF addresses', *hash[:rf_addresses])
      addrs = encode(serialize(*rf_addresses, esize: 3))
      [count, force, addrs].join(',')
    end
  end
end
