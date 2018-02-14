require_relative 'tcp/client'
require_relative 'udp/client'

HELP_KEYS = %w[h -h help -help --help ? -?].freeze

help = ARGV.size == 1 && HELP_KEYS.include?(ARGV.first)
wrong_args = ARGV.size > 2

if help || wrong_args
  puts "Wrong number of arguments: #{ARGV.size} (expected: 0..2)" if wrong_args
  puts "USAGE: ruby #{__FILE__} [<help>|<host>] [<port>]\n" \
       "  <help> - on of these: #{HELP_KEYS}\n\n" \
       "If no arguments are given, UDP discovery is performed.\n" \
       'Otherwise, TCP client is launched (unless help command entered).'
  exit
end

if ARGV.empty?
  puts "No arguments given - performing UDP discovery ...\n" \
       "(For usage message, type one of these: #{HELP_KEYS})\n\n"
  client = MaxCube::UDPClient.new
  client.discovery
  client.close
  exit
end

client = MaxCube::TCPClient.new
client.connect(*ARGV)
