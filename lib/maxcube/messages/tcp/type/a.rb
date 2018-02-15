
module MaxCube
  module Messages
    module TCP
      class Parser
        # Acknowledgement message to previous command
        # e.g. factory reset (a), delete a device (t), wake up (z).
        # Does not contain any data.
        module MessageA
          private

          def parse_tcp_a(_body)
            {}
          end
        end
      end

      class Serializer
        # Factory reset command.
        # Does not contain any data.
        # Acknowledgement (A) follows.
        module MessageA
          private

          def serialize_tcp_a(_hash)
            ''
          end
        end
      end
    end
  end
end
