
module MaxCube
  module Messages
    module TCP
      class Parser
        module MessageA
          private

          # Acknowledgement message to previous command
          # e.g. factory reset (a), delete a device (t), wake up (z)
          # Ignore all contents of the message
          def parse_tcp_a(_body)
            {}
          end
        end
      end

      class Serializer
        module MessageA
          private

          # Factory reset command
          # Does not contain any data
          # Acknowledgement (A) follows
          def serialize_tcp_a(_hash)
            ''
          end
        end
      end
    end
  end
end
