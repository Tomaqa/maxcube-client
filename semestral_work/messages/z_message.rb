
module MaxCube
  class MessageSerializer < MessageHandler
    private

    module MessageZ
    end

    # Wakeup command
    # Acknowledgement (A) follows
    def serialize_z(hash)
      time = format('%02x', hash[:time])
      scope = case hash[:scope]
              when :group, :room
                'G'
              when :all
                'A'
              when :device
                'D'
              end
      args = [time, scope]
      args << format('%02x', hash[:id]) if hash.include?(:id)
      args.join(',')
    end
  end
end
