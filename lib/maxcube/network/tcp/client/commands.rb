
module MaxCube
  module Network
    module TCP
      class Client
        # Provides handling of concrete commands from shell command line.
        module Commands
          private

          # List of commands and their aliases.
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

          # Returns usage message for a single command.
          # @param command [String] command key from {COMMANDS}.
          # @param args [String] arguments accepted by command.
          # @param description [String] description of command.
          # @param message [String, nil] optional message type
          #   that is about to be sent by the command.
          # @param response [String, nil] optional message type
          #   of expected response to this message.
          # @return [String] usage message for +command+.
          def usage_cmd(command, args, description,
                        message = nil, response = nil)
            cmds_str = (COMMANDS[command].dup << command).join('|')
            cmds_str << ' ' << args unless args.empty?

            description, *rest = description.split("\n")
            rest << "[#{message} message]" if message
            rest << "[#{response} response]" if response
            rest = if rest.empty?
                     ''
                   else
                     rest.map { |s| ' ' * 52 + s }.join("\n") << "\n"
                   end

            '  ' << cmds_str << ' ' * (48 - cmds_str.size) <<
              description << "\n" << rest
          end

          # Prints usage message composed mainly
          # from particular {#usage_cmd} calls.
          def cmd_usage
            puts "\nUSAGE: <command> [<arguments...>]\nCOMMADS:\n" <<
                 usage_cmd('usage', '',
                           'Prints this message') <<
                 usage_cmd('data', '',
                           'Lists buffered received data (hashes)') <<
                 usage_cmd('history', '',
                           'Lists all received data incl. the cleared') <<
                 usage_cmd('clear', '',
                           "Clears collected data\n" \
                           '(resp. moves it to history)') <<
                 usage_cmd('dump', '',
                           "Shortcut for 'data' + 'clear'") <<
                 usage_cmd('list', '',
                           'Requests for new list of devices', 'l', 'L') <<
                 usage_cmd('config', '',
                           'Requests for configuration message', 'c', 'C') <<
                 usage_cmd('send', '{}',
                           'Sends settings to connected devices',
                           's', 'S') <<
                 usage_cmd('pair', '{<timeout>}',
                           'Sets device into pairing mode' \
                           " with optional timeout\n" \
                           '(request for a new device)', 'n', 'N') <<
                 usage_cmd('ntp', '{<NTP servers...>}',
                           'Requests for NTP servers' \
                           ' and optionally updates them',
                           'f', 'F') <<
                 usage_cmd('url', '{<URL> <port>}',
                           'Configures Cube\'s portal URL', 'u') <<
                 usage_cmd('wake', '{<time> <scope> [<ID>]}',
                           'Wake-ups the Cube',
                           'z', 'A') <<
                 usage_cmd('metadata', '{}',
                           'Serializes metadata for the Cube',
                           'm', 'M') <<
                 usage_cmd('delete', '{<count> <force> <RF addresses...>}',
                           'Deletes one or more devices from the Cube (!)',
                           't', 'A') <<
                 usage_cmd('reset', '',
                           'Requests for factory reset (!)', 'a', 'A') <<
                 usage_cmd('verbose', '',
                           "Toggles verbose mode (whether is incoming data\n" \
                           'printed immediately or is not printed)') <<
                 usage_cmd('save', '[a|A|all]',
                           "Saves buffered [all] received and sent data\n" \
                           "into files at '#{@save_data_dir}'") <<
                 usage_cmd('load', '[<path>]',
                           'Loads first hash from YAML file' \
                           " to internal variable\n" \
                           "-> to pass data with outgoing message\n" \
                           'If path is relative,' \
                           " it looks in '#{@load_data_dir}'\n" \
                           "(loads previous valid hash if no file given)\n" \
                           '(command can be combined' \
                           " using '#{ARGS_FROM_HASH}'\n" \
                           ' with other commands' \
                           " which have '{}' arguments)") <<
                 usage_cmd('persist', '',
                           'Toggles persistent mode' \
                           "(whether is internal hash\n" \
                           'not invalidated after use)') <<
                 usage_cmd('quit', '',
                           "Shuts the client down gracefully\n" \
                           '(SIGINT and EOF also work)', 'q') <<
                 "\n[<arg>] means optional argument <arg>" \
                 "\n[<args...>] means multiple arguments <args...> or none" \
                 "\n  (<args...> requires at least one)" \
                 "\n{<arg>} means that either <arg>" \
                 " or '#{ARGS_FROM_HASH}' is expected" \
                 "\n  (when '#{ARGS_FROM_HASH}' specified as first argument," \
                 ' internal hash is used' \
                 "\n   -> 'load' command is called with rest arguments)" \
                 "\n  ({} means that only internal hash can be used," \
                 "\n   '#{ARGS_FROM_HASH}' is not necessary in this case)"
          end

          # Displays received hashes optionally with history.
          # Calls {#buffer}.
          # @param history [Boolean] whether to include history.
          def list_hashes(history)
            buffer(:recv, :hashes, history).each_with_index do |h, i|
              puts "<#{i + 1}>"
              print_hash(h)
              puts
            end
          end

          # Calls {#list_hashes} without history.
          def cmd_data
            list_hashes(false)
          end

          # Calls {#list_hashes} with history.
          def cmd_history
            list_hashes(true)
          end

          # Clears all buffered received data
          # (i.e. moves them to history).
          def cmd_clear
            %i[data hashes].each do |sym|
              @history[:recv][sym] += @buffer[:recv][sym]
              @buffer[:recv][sym].clear
            end
          end

          # Calls {#cmd_data} and {#cmd_clear}.
          def cmd_dump
            cmd_data
            cmd_clear
          end

          # Calls {#send_msg} with message type 'l'
          # (device list request).
          def cmd_list
            send_msg('l')
          end

          # Calls {#send_msg} with message type 'c'
          # (configuration message request).
          def cmd_config
            send_msg('c')
          end

          # Calls {#send_msg} with message type 's'
          # (send command message)
          # and +args+ and +load_only+ option.
          # @param args [Array<String>] arguments from command line.
          def cmd_send(*args)
            send_msg('s', *args, load_only: true)
          end

          # Calls {#send_msg} with message type 'n'
          # (new device request)
          # and +args+.
          # @param args [Array<String>] arguments from command line.
          def cmd_pair(*args)
            send_msg('n', *args)
          end

          # Calls {#send_msg} with message type 'u'
          # (set portal URL message)
          # and +args+.
          # @param args [Array<String>] arguments from command line.
          def cmd_url(*args)
            send_msg('u', *args)
          end

          # Calls {#send_msg} with message type 'f'
          # (NTP servers message)
          # and +args+ and +last_array+ option.
          # @param args [Array<String>] arguments from command line.
          def cmd_ntp(*args)
            send_msg('f', *args, last_array: true)
          end

          # Calls {#send_msg} with message type 'z'
          # (wake-up message)
          # and +args+.
          # @param args [Array<String>] arguments from command line.
          def cmd_wake(*args)
            send_msg('z', *args)
          end

          # Calls {#send_msg} with message type 'm'
          # (metadata message)
          # and +args+ and +load_only+ option.
          # @param args [Array<String>] arguments from command line.
          def cmd_metadata(*args)
            send_msg('m', *args, load_only: true)
          end

          # Calls {#send_msg} with message type 't'
          # (delete a device request)
          # and +args+, and +last_array+ and +array_nonempty+ options.
          # @param args [Array<String>] arguments from command line.
          def cmd_delete(*args)
            send_msg('t', *args, last_array: true, array_nonempty: true)
          end

          # Calls {#send_msg} with message type 'a'
          # (factory reset request).
          def cmd_reset
            send_msg('a')
          end

          def cmd_save(what = nil)
            buffer = !what
            all = %w[a A all].include?(what)
            unless all || buffer
              puts "Unrecognized argument: '#{what}'"
              return
            end

            dir = @save_data_dir + Time.now.strftime('%Y%m%d-%H%M')
            dir.mkpath

            %i[recv sent].each do |sym|
              data_fn = dir + (sym.to_s << '.data')
              File.open(data_fn, 'w') do |f|
                f.puts(buffer(sym, :data, all).join)
              end

              hashes_fn = dir + (sym.to_s << '.yaml')
              File.open(hashes_fn, 'w') do |f|
                buffer(sym, :hashes, all).to_yaml(f)
              end
            end

            which = buffer ? 'Buffered' : 'All'
            puts "#{which} received and sent raw data and hashes" \
                 " saved into '#{dir}'"
          rescue SystemCallError => e
            puts "Files could not been saved:\n#{e}"
          end

          def parse_hash(path)
            unless path.file? && path.readable?
              return puts "File is not readable: '#{path}'"
            end

            hash = YAML.load_file(path)
            hash = hash.first while hash.is_a?(Array)
            raise YAML::SyntaxError unless hash.is_a?(Hash)
            hash
          rescue YAML::SyntaxError => e
            puts "File '#{path}' does not contain proper YAML hash", e
          end

          def load_hash(path = nil)
            if path
              path = Pathname.new(path)
              path = @load_data_dir + path if path.relative?
              return parse_hash(path)
            end
            return @hash if @hash && @hash_set

            if @hash
              puts 'Internal hash is not set'
            else
              puts 'No internal hash loaded yet'
              cmd_usage
            end
          end

          def assign_hash(hash)
            valid_hash = !hash.nil?
            @hash = hash if valid_hash
            @hash_set |= valid_hash
            valid_hash
          end

          def cmd_load(path = nil)
            hash = load_hash(path)
            return false unless assign_hash(hash)
            print_hash(hash)
            true
          end

          # Helper method that 'toggles' boolean value and prints context info.
          # (It actually does not modify +flag+.)
          # @param name [String] variable name.
          # @param flag [Boolean] boolean value to be 'toggled'.
          # @return [Boolean] negated value of +flag+.
          def toggle(name, flag)
            puts "#{name}: #{flag} -> #{!flag}"
            !flag
          end

          # Calls {#toggle} with verbose mode variable.
          def cmd_verbose
            @verbose = toggle('verbose', @verbose)
          end

          # Calls {#toggle} with persist mode variable.
          def cmd_persist
            @persist = toggle('persist', @persist)
            @hash_set = @persist if @hash
          end

          # Manages to close the client gracefully
          # (it should lead to {#close}).
          def cmd_quit
            raise Interrupt
          end
        end
      end
    end
  end
end
