require 'maxcube/network'
require 'maxcube/messages/udp/parser'
require 'maxcube/messages/udp/serializer'

module MaxCube
  module Network
    # This module contains classes aimed onto UDP network tools
    # related to Cube protocol.
    module UDP
      # Common port used in Cube UDP communication.
      PORT = 23_272
    end
  end
end
