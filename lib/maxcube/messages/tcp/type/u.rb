
module MaxCube
  module Messages
    module TCP
      class Serializer
        # Command to configure Cube's portal URL
        module MessageU
          private

          # Mandatory hash keys.
          KEYS = %i[url port].freeze

          def serialize_tcp_u(hash)
            "#{hash[:url]}:#{to_int(0, 'port', hash[:port])}"
          end
        end
      end
    end
  end
end
