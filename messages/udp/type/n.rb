
module MaxCube
  module Messages
    module UDP
      class Parser
        module MessageN
          private

          KEYS = %i[ip_address gateway subnet_mask dns1 dns2].freeze

          def parse_udp_n(_body)
            KEYS.map do |k|
              [k, IPAddr.ntop(read(4))]
            end.to_h
          end
        end
      end
    end
  end
end
