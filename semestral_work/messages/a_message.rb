
module MaxCube
  class MessageReceiver < MessageHandler
    private

    module MessageA
    end

    # Acknowledgement message to previous factory reset
    # Ignore all contents of the message
    def parse_a(_body)
      {}
    end
  end
end
