require 'maxcube/network/tcp'
require_relative 'client/commands'

module MaxCube
  module Network
    module TCP
      # Fundamental class that provides TCP communication
      # with Cube gateway and connected devices.
      # After connecting to Cube ({#connect}),
      # interactive shell is launched.
      #
      # Communication with Cube is performed via messages,
      # whereas client works with hashes,
      # which have particular message contents divided
      # and is human readable.
      # An issue is how to pass contents of hashes
      # as arguments of message serialization.
      # For simple hashes client provides and option
      # to pass arguments explicitly on command line.
      # This would be difficult to accomplish
      # for large hashes with subhashes,
      # so YAML files are used in these cases,
      # which are able to be generated both automatically and manually.
      # This file has to be loaded into internal hash before each such message.
      #
      # Client interactive shell contains quite detailed usage message.
      class Client
        # Default verbose mode on startup.
        DEFAULT_VERBOSE = true
        # Default persist mode on startup.
        DEFAULT_PERSIST = true

        # Creates all necessary internal variables.
        # Internal hash is invalid on startup.
        # @param verbose [Boolean] verbose mode on startup.
        # @param persist [Boolean] persist mode on startup.
        def initialize(verbose: DEFAULT_VERBOSE, persist: DEFAULT_PERSIST)
          @parser = Messages::TCP::Parser.new
          @serializer = Messages::TCP::Serializer.new
          @queue = Queue.new

          @buffer = { recv: { hashes: [], data: [] },
                      sent: { hashes: [], data: [] } }
          @history = { recv: { hashes: [], data: [] },
                       sent: { hashes: [], data: [] } }

          @hash = nil
          @hash_set = false

          @data_dir = Pathname.new(MaxCube.data_dir)
          @load_data_dir = @data_dir + 'load'
          @save_data_dir = @data_dir + 'save'

          @verbose = verbose
          @persist = persist
        end

        # Connects to concrete address and starts interactive shell ({#shell}).
        # Calls {#receiver} in separate thread to receive all incoming messages.
        # @param host remote host address.
        # @param port remote host port.
        def connect(host = LOCALHOST, port = PORT)
          @socket = TCPSocket.new(host, port)
          @thread = Thread.new(self, &:receiver)
          shell
        end

        # Routine started in separate thread
        # that receives and parses all incoming messages in loop
        # and stores them info thread-safe queue.
        # Parsing is done via
        # {Messages::TCP::Parser#parse_tcp_msg}.
        # It should close gracefully on any +IOError+
        # or on shell's initiative.
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

        # Interactive shell that maintains all operations with Cube.
        # It is yet only simple +STDIN+ parser
        # without any command history and other features
        # that possess all decent shells.
        # It calls {#command} on every input.
        # It provides quite detailed usage message ({#cmd_usage}).
        #
        # It should close gracefully
        # from user's will, when connection closes,
        # or when soft interrupt appears.
        # Calls {#close} when closing.
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

        # Closes client gracefully.
        def close
          STDIN.close
          send_msg('q')
          @socket.close
          @thread.join
        end

        private

        # Moves contents of receiver's queue to internal buffer.
        # Queue is being filled from {#receiver}.
        # Operation is thread-safe.
        def refresh_buffer
          until @queue.empty?
            data, hashes = @queue.pop
            @buffer[:recv][:data] << data
            @buffer[:recv][:hashes] << hashes
          end
        end

        # Returns only current or all (without or with history)
        # collected part of buffer and history
        # (contents of buffer is moved to history on clear command).
        # @param dir_key [:recv, :sent] received or sent data.
        # @param data_key [:hashes, :data] hashes or raw data (set of messages).
        # @param history [Boolean] whether to include history.
        # @return [Array<Hash>, String] demanded data.
        def buffer(dir_key, data_key, history = false)
          return @buffer[dir_key][data_key] unless history
          @history[dir_key][data_key] + @buffer[dir_key][data_key]
        end

        # Executes command from shell command line.
        # It calls a method dynamically according to {COMMANDS},
        # or displays usage message {#cmd_usage}.
        # @param line [String] command line from +STDIN+
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

        include Commands

        # Zips +args+ with appropriate keys
        # according to {Messages::Handler#msg_type_hash_keys}
        # and {Messages::Handler#msg_type_hash_opt_keys}.
        # @param type [String] message type.
        # @param args [Array<String>] arguments from command line.
        # @param opts [Hash] options that modifies interpreting of +args+.
        # @option opts [Boolean] :last_array whether to insert
        #   all rest arguments into array that will be stored into the last key.
        # @option opts [Boolean] :array_nonempty whether to require +last_array+
        #   _not_ to be empty.
        # @return [Hash, nil] resulting hash, or +nil+ on failure.
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
            return puts 'Additional arguments: ' \
                        "#{args.last(args.size - keys.size)}"
          end
          keys.zip(args).to_h.reject { |_, v| v.nil? }
        end

        # Returns hash via {#cmd_load}.
        # It is used to combine sending a message with loading a hash from file.
        # On success and in non-persistive mode,
        # it simultaneously invalidates internal hash flag.
        # @param args [Array<String>] arguments from command line.
        # @return [Hash, nil] loaded hash, or +nil+ on failure.
        def send_msg_hash_from_internal(*args, **_opts)
          return nil unless cmd_load(*args.drop(1))
          @hash_set = false unless @persist
          @hash
        end

        # Command line token that enables loading arguments (hash) from file.
        ARGS_FROM_HASH = '-'.freeze

        # @param args [Array<String>] arguments from command line.
        # @return [Boolean] whether to enable loading arguments (hash)
        #   from file.
        def args_from_hash?(args)
          args.first == ARGS_FROM_HASH
        end

        # Returns hash with contents necessary for serialization
        # of message of given message type.
        # It is either built from command line +args+
        # ({#send_msg_hash_from_keys_args}),
        # or loaded from YAML file ({#send_msg_hash_from_internal}).
        # @param type [String] message type.
        # @param args [Array<String>] arguments from command line.
        # @param opts [Hash] options that modifies interpreting of +args+.
        # @option opts [Boolean] :load_only means that hash
        #   must be loaded from file (contents are too complex).
        #   Specifying {ARGS_FROM_HASH} is optional in this case.
        # @return [Hash] resulting hash.
        def send_msg_hash(type, *args, **opts)
          if opts[:load_only] && !args_from_hash?(args)
            args.unshift(ARGS_FROM_HASH)
          end
          return {} if args.empty?

          if args_from_hash?(args)
            return send_msg_hash_from_internal(*args, **opts)
          end

          send_msg_hash_from_keys_args(type, *args, **opts)
        end

        # Performs message serialization and sends it to Cube.
        # It builds the hash to serialize from by {#send_msg_hash},
        # and serializes it with
        # {Messages::TCP::Serializer#serialize_tcp_hash}.
        #
        # Both sent message and built hash are buffered.
        #
        # It catches all {Messages::InvalidMessage} exceptions.
        # @param type [String] message type.
        # @param args [Array<String>] arguments from command line.
        # @param opts [Hash] options that modifies interpreting of +args+.
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

        # Prints hash in human readable way.
        # @param hash [Hash] input hash.
        def print_hash(hash)
          puts hash.to_yaml
        end
      end
    end
  end
end
