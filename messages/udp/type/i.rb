
module MaxCube
  module Messages
    module UDP
      class Parser
        module MessageI
          private

          def parse_udp_i
            {
              rf_address: read(3, true),
              firmware_version: read(2),
            }
          end
        end
      end
    end
  end
end
