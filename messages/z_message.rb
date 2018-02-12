
module MaxCube
  class MessageSerializer < MessageHandler
    private

    module MessageZ
      KEYS = %i[time scope].freeze
      OPT_KEYS = %i[id].freeze
    end

    # Wakeup command
    # Acknowledgement (A) follows
    def serialize_z(hash)
      time = format('%02x', hash[:time])
      scope = hash[:scope].to_sym
      scope = case scope
              when :group, :room
                'G'
              when :all
                'A'
              when :device
                'D'
              else raise InvalidMessageBody
                .new(@msg_type, "invalid scope: #{scope}")
              end
      args = [time, scope]
      args << format('%02x', hash[:id]) if hash.include?(:id)
      args.join(',')
    end
  end
end
