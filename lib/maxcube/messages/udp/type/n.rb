
module MaxCube
  module Messages
    module UDP
      class Parser
        # Get network address message.
        module MessageN
          private

          # Local keys without the common ones.
          N_KEYS = %i[ip_address gateway subnet_mask dns1 dns2].freeze
          # Mandatory keys.
          KEYS = (Parser::KEYS + N_KEYS).freeze

          def parse_udp_n(_body)
            N_KEYS.map do |k|
              [k, IPAddr.ntop(read(4))]
            end.to_h
          end
        end
      end
    end
  end
end
