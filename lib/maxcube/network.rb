require 'socket'

require 'yaml'

require 'maxcube'

module MaxCube
  # Encapsulates network structures providing clients and servers
  # that comply Cube messages protocol.
  # It utilizes parsing and serializing features from {Messages}.
  module Network
    # Common localhost IP address.
    LOCALHOST = 'localhost'.freeze
    # Common broadcast IP address.
    BROADCAST = '<broadcast>'.freeze
  end
end
