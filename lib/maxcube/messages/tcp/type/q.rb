
module MaxCube
  module Messages
    module TCP
      class Serializer
        module MessageQ
          private

          # Quit message - terminates connection
          # Does not contain any data
          def serialize_tcp_q(_hash)
            ''
          end
        end
      end
    end
  end
end
