
module MaxCube
  module Messages
    module UDP
      class Parser
        module MessageI
          private

          KEYS = %i[rf_address firmware_version].freeze

          def parse_udp_i(_body)
            {
              rf_address: read(3, true),
              firmware_version: read(2, 'H*'),
            }
          end
        end
      end
    end
  end
end
