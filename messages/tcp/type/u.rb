
module MaxCube
  module Messages
    module TCP
      class Serializer
        module MessageU
          private

          KEYS = %i[url port].freeze

          # Command to configure Cube's portal URL
          def serialize_tcp_u(hash)
            "#{hash[:url]}:#{to_int(0, 'port', hash[:port])}"
          end
        end
      end
    end
  end
end
