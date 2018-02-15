require 'maxcube/messages'

module MaxCube
  module Messages
    # This module contains classes aimed onto TCP messages of Cube protocol.
    #
    # Structure of every TCP Cube message:
    # * Starts with single letter followed by +:+
    # * Ends with +\\r\\n+
    # * Except of the end, it contains only printable characters.
    # As all messages are being split by +\\r\\n+,
    # it does not occur in single message processing,
    # only in raw data processing.
    # @example
    #   X:message\r\n
    module TCP
      # Maximum length of TCP Cube message
      # without +\\r\\n+ (with it it would be 1900)
      MSG_MAX_LEN = 1898
    end
  end
end
