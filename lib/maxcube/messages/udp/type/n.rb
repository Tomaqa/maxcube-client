
module MaxCube
  module Messages
    module UDP
      class Parser
        module MessageN
          private

          N_KEYS = %i[ip_address gateway subnet_mask dns1 dns2].freeze
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
