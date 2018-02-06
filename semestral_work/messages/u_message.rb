
module MaxCube
  class MessageSerializer < MessageHandler
    private

    module MessageU
    end

    # Command to configure Cube's portal URL
    def serialize_u(hash)
      "#{hash[:url]}:#{hash[:port]}"
    end
  end
end
