
module MaxCube
  module Messages
    module UDP
      class Parser
        module MessageI
          private

          KEYS = (Parser::KEYS + %i[unknown
                                    rf_address firmware_version]).freeze

          def parse_udp_i(_body)
            {
              unknown: read(1),
              rf_address: read(3, true),
              firmware_version: read(2, 'H*'),
            }
          end
        end
      end
    end
  end
end
