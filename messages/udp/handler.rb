require_relative 'udp'
require_relative '../handler'

require 'ipaddr'

module MaxCube
  module Messages
    module UDP
      module Handler
        include Messages::Handler
      end
    end
  end
end
