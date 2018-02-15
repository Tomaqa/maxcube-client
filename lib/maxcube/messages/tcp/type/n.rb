
module MaxCube
  module Messages
    module TCP
      class Parser
        # New device (pairing) message.
        module MessageN
          private

          # Mandatory hash keys.
          KEYS = %i[device_type rf_address serial_number unknown].freeze

          def parse_tcp_n(body)
            @io = StringIO.new(decode(body), 'rb')

            {
              device_type: device_type(read(1, true)),
              rf_address: read(3, true),
              serial_number: read(10),
              unknown: read(1),
            }
          rescue IOError
            raise InvalidMessageBody
              .new(@msg_type, 'unexpected EOF reached')
          end
        end
      end

      class Serializer
        # Command to set the Cube into pairing mode
        # with optional +timeout+ in seconds.
        module MessageN
          private

          # Optional hash keys.
          OPT_KEYS = %i[timeout].freeze

          def serialize_tcp_n(hash)
            return '' unless hash.key?(:timeout)
            format('%04x', to_int(0, 'timeout', hash[:timeout]))
          end
        end
      end
    end
  end
end
