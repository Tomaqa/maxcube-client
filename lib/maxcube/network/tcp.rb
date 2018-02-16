require 'maxcube/network'
require 'maxcube/messages/tcp/parser'
require 'maxcube/messages/tcp/serializer'

module MaxCube
  module Network
    # This module contains classes aimed onto TCP network tools
    # related to Cube protocol.
    module TCP
      # Common port used in Cube TCP communication.
      PORT = 62_910
    end
  end
end
