
module MaxCube
  module Messages
    module TCP
      class Serializer
        # Wakeup command.
        # Acknowledgement (A) follows.
        module MessageZ
          private

          # Mandatory hash keys.
          KEYS = %i[time scope].freeze
          # Optional hash keys.
          OPT_KEYS = %i[id].freeze

          def serialize_tcp_z(hash)
            time = format('%02x', to_int(0, 'time', hash[:time]))
            scope = hash[:scope].to_sym
            scope = case scope
                    when :group, :room
                      'G'
                    when :all
                      'A'
                    when :device
                      'D'
                    else
                      raise InvalidMessageBody.new(@msg_type,
                                                   "invalid scope: #{scope}")
                    end
            args = [time, scope]
            args << format('%02x', to_int(0, 'ID', hash[:id])) if hash.key?(:id)
            args.join(',')
          end
        end
      end
    end
  end
end
