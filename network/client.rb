require_relative '../messages/messages'
require 'socket'
require 'thread'

require 'pp'
require 'yaml'

module MaxCube
  class Client
    attr_accessor :socket
    attr_reader :parser, :serializer

    def initialize
      @parser = MessageParser.new
      @serializer = MessageSerializer.new
      @queue = Queue.new

      @buffer = { recv: { hashes: [], data: [] },
                  sent: { hashes: [], data: [] } }
      @history = { recv: { hashes: [], data: [] },
                   sent: { hashes: [], data: [] } }

      @hash = {}
      @hash_set = false

      @verbose = true
      @persist = true
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
        refresh_buffer
        command(line)
        puts
      end
      raise Interrupt
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
        hashes = @parser.parse_data(data)
        if @verbose
          hashes.each { |h| print_hash(h) }
          puts
        end
        @queue << [data, hashes]
      end
      raise IOError
    rescue IOError
      STDIN.close
      puts '<Closing receiver thread ...>'
    rescue MessageHandler::InvalidMessage => e
      puts e.to_s.capitalize
    end

    private

    COMMANDS = {
      'usage' => %w[? h help],
      'data' => %w[B buffer d],
      'history' => %w[H hist],
      'clear' => %w[C],
      'dump' => %w[D],
      'list' => %w[l],
      'config' => %w[c],
      'pair' => %w[n],
      'url' => %w[U u],
      'ntp' => %w[N f],
      'wake' => %w[w z],
      'delete' => %w[del],
      'reset' => %w[],
      'verbose' => %w[V],
      'save' => %w[S],
      'load' => %w[L],
      'persist' => %w[P],
      'quit' => %w[q],
    }.freeze

    def refresh_buffer
      until @queue.empty?
        data, hashes = @queue.pop
        @buffer[:recv][:data] << data
        @buffer[:recv][:hashes] << hashes
      end
    end

    def buffer(dir_key, data_key, history = false)
      return @buffer[dir_key][data_key] unless history
      @history[dir_key][data_key] + @buffer[dir_key][data_key]
    end

    def command(line)
      cmd, *args = line.chomp.split
      return nil unless cmd

      return send("cmd_#{cmd}", *args) if COMMANDS.key?(cmd)

      keys = COMMANDS.find { |_, v| v.include?(cmd) }
      return send("cmd_#{keys[0]}", *args) if keys

      puts "Unrecognized command: '#{cmd}'"
      cmd_usage
    rescue ArgumentError
      puts "Invalid arguments: #{args}"
      cmd_usage
    end

    def send_msg_hash_keys_args(type, *args, **kwargs)
      keys = @serializer.serialize_msg_type_keys(type) +
             @serializer.serialize_msg_type_optional_keys(type)
      if kwargs[:array]
        hash_args = args.first(keys.size - 1)
        ary_args = args.drop(keys.size - 1)
        ary_args = nil if kwargs[:array_nonempty] && ary_args.empty?
        args = hash_args << ary_args
      end
      return [keys, args] unless keys.size < args.size
      puts "Additional arguments: #{args.last(args.size - keys.size)}"
      nil
    end

    def send_msg_hash(type, *args, **kwargs)
      return {} if args.empty?

      from_hash = args == %w[-]
      if from_hash
        unless @hash_set
          puts 'No internal hash loaded.' \
               " Use 'load' command or pass proper arguments."
          cmd_usage
          return nil
        end
        @hash_set = false unless @persist
        return @hash
      end

      keys, args = send_msg_hash_keys_args(type, *args, **kwargs)
      return nil unless keys
      keys.zip(args).to_h.reject { |_, v| v.nil? }
    end

    def send_msg(type, *args, **kwargs)
      hash = send_msg_hash(type, *args, **kwargs)
      return unless hash
      hash[:type] = type
      msg = @serializer.serialize_hash(hash)

      @buffer[:sent][:data] << msg
      @buffer[:sent][:hashes] << [hash]
      @socket.write(msg)
    rescue MessageHandler::InvalidMessage => e
      puts e.to_s.capitalize
    end

    def print_hash(hash)
      puts hash.to_yaml
    end

    require_relative 'commands'
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
