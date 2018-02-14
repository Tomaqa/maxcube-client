
module MaxCube
  module Messages
    module TCP
      class Parser
        module MessageF
          private

          # NTP server message
          def parse_tcp_f(body)
            { ntp_servers: body.split(',') }
          end
        end
      end

      class Serializer
        module MessageF
          private

          OPT_KEYS = %i[ntp_servers].freeze

          # Request for NTP servers message (F)
          # Optionally, updates can be done
          def serialize_tcp_f(hash)
            hash.key?(:ntp_servers) ? hash[:ntp_servers].join(',') : ''
          end
        end
      end
    end
  end
end
