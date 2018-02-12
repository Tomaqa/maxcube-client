
module MaxCube
  class MessageSerializer < MessageHandler
    private

    module MessageU
      KEYS = %i[url port].freeze
    end

    # Command to configure Cube's portal URL
    def serialize_u(hash)
      "#{hash[:url]}:#{hash[:port]}"
    end
  end
end
