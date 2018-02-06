
module MaxCube
  class MessageParser < MessageHandler
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

  class MessageSerializer < MessageHandler
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
