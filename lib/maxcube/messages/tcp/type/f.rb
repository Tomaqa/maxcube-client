
module MaxCube
  module Messages
    module TCP
      class Parser
        # NTP server message.
        module MessageF
          private

          # Mandatory hash keys.
          KEYS = %i[ntp_servers].freeze

          def parse_tcp_f(body)
            { ntp_servers: body.split(',') }
          end
        end
      end

      class Serializer
        # Request for NTP servers message (F).
        # Optionally, updates can be done.
        module MessageF
          private

          # Optional hash keys.
          OPT_KEYS = %i[ntp_servers].freeze

          def serialize_tcp_f(hash)
            hash.key?(:ntp_servers) ? hash[:ntp_servers].join(',') : ''
          end
        end
      end
    end
  end
end
