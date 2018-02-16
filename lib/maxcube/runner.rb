require 'maxcube/network/tcp/client'
require 'maxcube/network/udp/client'

module MaxCube
  # Module that provides running of Cube clients:
  # {Network::TCP::Client} and {Network::UDP::Client}
  class Runner
    # These will display help message.
    HELP_KEYS = %w[h -h help -help --help ? -?].freeze

    # Assigns command line arguments to internal variable.
    def initialize(argv)
      @argv = argv
    end

    # Runs either TCP or UDP client.
    def run
      help = @argv.size == 1 && HELP_KEYS.include?(@argv.first)
      wrong_args = @argv.size > 2

      if help || wrong_args
        if wrong_args
          puts "Wrong number of arguments: #{@argv.size} (expected: 0..2)"
        end
        puts "USAGE: ruby #{__FILE__} [<help>|<host>] [<port>]\n" \
             "  <help> - on of these: #{HELP_KEYS}\n\n" \
             "If no arguments are given, UDP discovery is performed.\n" \
             'Otherwise, TCP client is launched (unless help command entered).'
        exit
      end

      if @argv.empty?
        puts "No arguments given - performing UDP discovery ...\n" \
             "(For usage message, type one of these: #{HELP_KEYS})\n\n"
        client = MaxCube::Network::UDP::Client.new
        client.discovery
        client.close
        exit
      end

      client = MaxCube::Network::TCP::Client.new
      client.connect(*@argv)
    end
  end
end
