
module MaxCube
  # Acknowledgement message to previous reset
  # Ignore all contents of the message
  class MessageReceiver < MessageHandler
    def parse_a(_body)
      {}
    end
  end
end
