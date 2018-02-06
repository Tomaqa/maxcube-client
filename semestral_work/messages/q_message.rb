
module MaxCube
  class MessageSerializer < MessageHandler
    private

    module MessageQ
    end

    # Quit message - terminates connection
    # Does not contain any data
    def serialize_q(_hash)
      ''
    end
  end
end
