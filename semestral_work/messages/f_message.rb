
module MaxCube
  class MessageReceiver < MessageHandler
    private

    module MessageF
    end

    # NTP server message
    def parse_f(body)
      { ntp_servers: body.split(',') }
    end
  end
end
