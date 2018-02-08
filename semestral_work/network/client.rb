require_relative '../messages/messages'
require 'socket'
require 'thread'

module MaxCube
  class Client
    attr_accessor :socket
    attr_reader :parser, :serializer

    def initialize
      @parser = MessageParser.new
      @serializer = MessageSerializer.new
      @buffer = Queue.new
    end

    def connect(host, port)
      @socket = TCPSocket.new(host, port)
      @thread = Thread.new(self, &:receiver)
      shell
    end

    def send_msg(type, hash = {})
      hash[:type] = type
      msg = @serializer.serialize_hash(hash)
      @socket.write(msg)
      STDIN.close if type == 'q'
    end

    def shell
      puts "Welcome to interactive shell!\n\n"
      ARGF.each do |line|
        line = line.split[0]
        send_msg(line)
      end
      raise IOError
    rescue IOError, Interrupt
      puts "\nClosing shell ..."
      close
    end

    def close
      send_msg('q')
      @socket.close
      @thread.join
    end

    def receiver
      puts '<Starting receiver thread ...>'
      while data = @socket.gets
        ary = @parser.parse_data(data)
        p ary
      end
      raise IOError
    rescue IOError
      puts '<Closing receiver thread ...>'
    end
  end
end

client = MaxCube::Client.new
# client.connect('localhost', 23)
client.connect('localhost', 2000)
