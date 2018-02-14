require 'maxcube/messages'

module MaxCube
  module Messages
    # Structure of message:
    # * Starts with single letter followed by ':'
    # * Ends with "\r\n"
    # Example (unencoded):
    # X:message\r\n
    # As all messages are being split by "\r\n",
    # it does not occur in single message processing,
    # only in raw data processing.
    module TCP
      # Without "\r\n", with it it is 1900
      MSG_MAX_LEN = 1898
    end
  end
end
