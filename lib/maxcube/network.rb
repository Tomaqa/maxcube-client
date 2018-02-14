require 'socket'
require 'thread'
require 'ipaddr'
require 'pathname'

require 'pp'
require 'yaml'

module MaxCube
  module Network
    LOCALHOST = 'localhost'.freeze
    BROADCAST = '<broadcast>'.freeze
  end
end
