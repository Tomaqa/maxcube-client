
module MaxCube
  # class MessageParser < MessageHandler
  class Messages
    module Parser
      module TCP
    private

    module MessageA
    end

    # Acknowledgement message to previous command
    # e.g. factory reset (a), delete a device (t), wake up (z)
    # Ignore all contents of the message
    def parse_a(_body)
      {}
    end
  end
end

  # class MessageSerializer < MessageHandler
  module Serializer
      module TCP
    private

    module MessageA
    end

    # Factory reset command
    # Does not contain any data
    # Acknowledgement (A) follows
    def serialize_a(_hash)
      ''
    end
  end
end
end
end
