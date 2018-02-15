
module MaxCube
  module Messages
    module UDP
      class Parser
        # Get URL information message.
        module MessageH
          private

          # Mandatory keys.
          KEYS = (Parser::KEYS + %i[port url path]).freeze

          def parse_udp_h(_body)
            port = read(2, true)
            url, path = read.split(',')
            {
              port: port,
              url: url,
              path: path,
            }
          end
        end
      end
    end
  end
end
