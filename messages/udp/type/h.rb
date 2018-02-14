
module MaxCube
  module Messages
    module UDP
      class Parser
        module MessageH
          private

          def parse_udp_h
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
