
module MaxCube
  module Messages
    module UDP
      class Parser
        module MessageN
          private

          def parse_udp_n
            %i[ip_address gateway subnet_mask dns1 dns2].map do |k|
              [k, IPAddr.ntop(read(4))]
            end.to_h
          end
        end
      end
    end
  end
end
