require 'socket'
require 'thread'

require 'pathname'
require 'pp'
require 'yaml'

require_relative '../../../messages//tcp/parser'
require_relative '../../../messages/tcp/serializer'

require_relative 'commands'

module MaxCube
  class TCPClient
    LOCALHOST = 'localhost'.freeze
    PORT = 62_910

    def initialize
      @parser = Messages::TCP::Parser.new
      @serializer = Messages::TCP::Serializer.new
      @queue = Queue.new

      @buffer = { recv: { hashes: [], data: [] },
                  sent: { hashes: [], data: [] } }
      @history = { recv: { hashes: [], data: [] },
                   sent: { hashes: [], data: [] } }

      @hash = nil
      @hash_set = false

      @data_dir = Pathname.new('data')
      @load_data_dir = @data_dir + 'load'
      @save_data_dir = @data_dir + 'save'

      @verbose = true
      @persist = true
    end

    def connect(host = LOCALHOST, port = PORT)
      @socket = TCPSocket.new(host, port)
      @thread = Thread.new(self, &:receiver)
      shell
    end

    def receiver
      puts '<Starting receiver thread ...>'
      while (data = @socket.gets)
        hashes = @parser.parse_tcp_data(data)
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
    rescue Messages::InvalidMessage => e
      puts e.to_s.capitalize
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

    private

    COMMANDS = {
      'usage' => %w[? h help],
      'data' => %w[B buffer d],
      'history' => %w[H hist],
      'clear' => %w[C],
      'dump' => %w[D],
      'list' => %w[l],
      'config' => %w[c],
      'send' => %w[cmd s set],
      'pair' => %w[n],
      'ntp' => %w[N f],
      'url' => %w[U u],
      'wake' => %w[w z],
      'metadata' => %w[m meta],
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
      return send("cmd_#{keys.first}", *args) if keys

      puts "Unrecognized command: '#{cmd}'"
      cmd_usage
    rescue ArgumentError
      puts "Invalid arguments: #{args}"
      cmd_usage
    end

    def send_msg_hash_from_keys_args(type, *args, **opts)
      keys = @serializer.msg_type_hash_keys(type) +
             @serializer.msg_type_hash_opt_keys(type)
      if opts[:last_array]
        hash_args = args.first(keys.size - 1)
        ary_args = args.drop(keys.size - 1)
        ary_args = nil if opts[:array_nonempty] && ary_args.empty?
        args = hash_args << ary_args
      end
      if keys.size < args.size
        return puts "Additional arguments: #{args.last(args.size - keys.size)}"
      end
      keys.zip(args).to_h.reject { |_, v| v.nil? }
    end

    def send_msg_hash_from_internal(*args, **_opts)
      return nil unless cmd_load(*args.drop(1))
      @hash_set = false unless @persist
      @hash
    end

    ARGS_FROM_HASH = '-'.freeze

    def args_from_hash?(args)
      args.first == ARGS_FROM_HASH
    end

    def send_msg_hash(type, *args, **opts)
      args.unshift(ARGS_FROM_HASH) if opts[:load_only] && !args_from_hash?(args)
      return {} if args.empty?

      return send_msg_hash_from_internal(*args, **opts) if args_from_hash?(args)

      send_msg_hash_from_keys_args(type, *args, **opts)
    end

    def send_msg(type, *args, **opts)
      hash = send_msg_hash(type, *args, **opts)
      return unless hash

      if hash.key?(:type)
        unless type == hash[:type]
          puts "\nInternal hash message type mismatch: '#{hash[:type]}'" \
               " (should be '#{type}')"
          return
        end
      else
        hash[:type] = type
      end
      msg = @serializer.serialize_tcp_hash(hash)

      @buffer[:sent][:data] << msg
      @buffer[:sent][:hashes] << [hash]
      @socket.write(msg)
    rescue Messages::InvalidMessage => e
      puts e.to_s.capitalize
    end

    def print_hash(hash)
      puts hash.to_yaml
    end
  end
end
