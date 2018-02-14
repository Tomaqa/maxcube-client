
module MaxCube
  module Messages
    module UDP
      class Parser
        module MessageH
          private

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
