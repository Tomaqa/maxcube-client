
module MaxCube
  module Messages
    module TCP
      class Serializer
        # Command to delete one or more devices from the Cube.
        # Acknowledgement (A) follows.
        module MessageT
          private

          # Mandatory hash keys.
          # +count+ key would cause ambuigity if it was optional
          # due to +rf_addresses+ has variable size.
          KEYS = %i[count force rf_addresses].freeze

          def serialize_tcp_t(hash)
            force = to_bool('force mode', hash[:force]) ? '1' : '0'
            rf_addresses = to_ints(0, 'RF addresses', *hash[:rf_addresses])
            count = to_int(0, 'count', hash[:count])

            unless count == rf_addresses.size
              raise InvalidMessageBody
                .new(@msg_type,
                     'count and number of devices mismatch: ' \
                     "#{count} != #{rf_addresses.size}")
            end
            if count.zero?
              raise InvalidMessageBody
                .new(@msg_type, 'no device specified')
            end

            addrs = encode(serialize(*rf_addresses, esize: 3))
            [format('%02x', count), force, addrs].join(',')
          end
        end
      end
    end
  end
end
