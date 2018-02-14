require 'socket'
require 'yaml'

require_relative '../../../messages//udp/parser'
require_relative '../../../messages/udp/serializer'

module MaxCube
  class UDPClient
    BROADCAST = '<broadcast>'.freeze
    PORT = 23_272

    def initialize(port = PORT)
      @socket = UDPSocket.new
      @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      @port = port

      @parser = Messages::UDP::Parser.new
      @serializer = Messages::UDP::Serializer.new
    end

    def send_msg(msg, addr = BROADCAST)
      @socket.send(msg, 0, addr, @port)
    end

    def recv_msg
      msg, addr = @socket.recvfrom(1024)
      port = addr[1]
      ipaddr = addr[3]
      [msg, ipaddr, port]
    rescue Interrupt
      puts 'Aborted'
    end

    def send_recv_hash(hash, addr = BROADCAST)
      msg = @serializer.serialize_udp_hash(hash)
      send_msg(msg, addr)
      msg, addr, port = recv_msg
      return nil unless msg
      hash = @parser.parse_udp_msg(msg)
      puts "'#{hash[:type]}' response from #{addr}:#{port}:\n#{hash.to_yaml}\n"
      hash
    end

    def discovery
      puts "Starting discovery ...\n\n"
      send_recv_hash(type: 'I')
    end

    def close
      puts "\nClosing client ..."
      @socket.close
    end
  end
end
