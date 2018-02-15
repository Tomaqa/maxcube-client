
module MaxCube
  module Messages
    module TCP
      class Serializer
        # Quit message - terminates connection.
        # Does not contain any data.
        module MessageQ
          private

          def serialize_tcp_q(_hash)
            ''
          end
        end
      end
    end
  end
end
