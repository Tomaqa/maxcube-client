require 'maxcube/messages'

module MaxCube
  module Messages
    # This module contains classes aimed onto UDP messages of Cube protocol.
    #
    # Structure of every UDP Cube message:
    # * Starts with {MSG_PREFIX}
    # @example
    #   eQ3MaxApKEQ0523864>I
    module UDP
      # Prefix of any UDP Cube message
      MSG_PREFIX = 'eQ3Max'.freeze
    end
  end
end
