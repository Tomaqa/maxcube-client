require_relative '../messages/messages'
require 'socket'
require 'thread'
require 'pp'

module MaxCube
  class Client
    attr_accessor :socket
    attr_reader :parser, :serializer

    def initialize
      @parser = MessageParser.new
      @serializer = MessageSerializer.new
      @buffer = Queue.new
      @hashes = []

      @verbose = true
    end

    def connect(host = 'localhost', port = 2000)
      @socket = TCPSocket.new(host, port)
      @thread = Thread.new(self, &:receiver)
      shell
    end

    def shell
      puts "Welcome to interactive shell!\n" \
           "Type 'help' for list of commands.\n\n"
      STDIN.each do |line|
        refresh_hashes
        cmd(line)
      end
      raise IOError
    rescue IOError, Interrupt
      puts "\nClosing shell ..."
      close
    end

    def close
      STDIN.close
      send_msg('q')
      @socket.close
      @thread.join
    end

    def receiver
      puts '<Starting receiver thread ...>'
      while (data = @socket.gets)
        ary = @parser.parse_data(data)
        ary.each { |a| pp a } if @verbose
        @buffer << ary
      end
      raise IOError
    rescue IOError
      STDIN.close
      puts '<Closing receiver thread ...>'
    end

    private

    def cmd(line)
      words = line.chomp.split
      cmd = words[0]
      return unless cmd

      case cmd
      when '?', 'h', 'help', 'usage'
        usage
      when 'd', 'data'
        list_hashes
      when 'C', 'clear'
        clear
      when 'D', 'dump'
        list_hashes
        clear
      when 'l', 'list'
        send_msg('l')
      when 'c', 'config'
        send_msg('c')
      when 'n', 'pair'
        send_msg('n')
      when 'reset'
        send_msg('a')
      when 'V', 'verbose'
        @verbose = true
      when 'Q', 'quiet'
        @verbose = false
      when 'q', 'quit'
        raise Interrupt
      else
        puts "Unrecognized command: '#{cmd}'"
        usage
      end
    end

    def send_msg(type, hash = {})
      hash[:type] = type
      msg = @serializer.serialize_hash(hash)
      @socket.write(msg)
    end

    def clear
      @hashes = []
    end

    def refresh_hashes
      @hashes += @buffer.pop until @buffer.empty?
    end

    def list_hashes
      @hashes.each do |h|
        pp h
      end
      puts
    end

    def usage
      puts "\nUSAGE: <command> [arguments]\n" \
           "COMMADS:\n" \
           "   ?|h|help|usage     Prints this message\n" \
           "   d|data             Lists all received data (hashes)\n" \
           "   C|clear            Clears collected data (hashes)\n" \
           "   D|dump             Shortcut for 'data' + 'clear'\n" \
           "   l|list             Requests for new list of devices\n" \
           "                        [L response]\n" \
           "   c|config           Requests for configuration message\n" \
           "                        [C response]\n" \
           '   n|pair             Sets device into pairing mode ' \
                                    "(request for a new device)\n" \
           "                        [N response]\n" \
           "   reset              Requests for factory reset (!)\n" \
           "                        [A response]\n" \
           '   V|verbose          Verbose mode (incoming messages ' \
                                    "are printed immediately)\n" \
           '   Q|quiet            Quiet mode (incoming messages ' \
                                    "are not printed)\n" \
           "   q|quit             Shuts the client down gracefully\n" \
           "                        (SIGINT and EOF also work)\n" \
           "\n"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  unless ARGV.size <= 2
    puts "Wrong number of arguments: #{ARGV.size} (expected: 0..2)"
    puts "Usage: ruby #{__FILE__} [host] [port]"
    exit
  end

  client = MaxCube::Client.new
  client.connect(*ARGV)
end
