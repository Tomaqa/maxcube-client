require 'socket'

module MaxCube
  class SampleServer
    def initialize(port)
      @port = port
      @server = TCPServer.new(port)
    end

    def run
      puts "Starting server on port #{@port} ...\n\n"
      loop do
        Thread.start(@server.accept) do |client|
          puts "Accepting #{client.addr[3]}:#{client.addr[1]} ..."
          send_msg(client, msg_h)
          send_msg(client, msg_l)
          loop do
            msg = client.gets
            if !msg || msg == "q:\r\n"
              puts "Closing #{client.addr[3]}:#{client.addr[1]} ..."
              client.close
              Thread.stop
            end
            puts "Income message: '#{msg.chomp}'"
            cmd(client, msg)
          end
        end
      end
    rescue Interrupt
      close
    end

    def send_msg(client, msg)
      client.puts(msg << "\r\n")
    end

    private

    def cmd(client, msg)
      type, _body = msg.split(':')
      case type
      when 'a'
        send_msg(client, msg_a)
      when 'c'
        send_msg(client, msg_c)
      when 'l'
        send_msg(client, msg_l)
      when 'n'
        send_msg(client, msg_n)
      end
    end

    def msg_a
      'A:'
    end

    def msg_c
      'C:01b491,EQG0kQUAEg9KRVEwMzA1MjA1'
    end

    def msg_h
      'H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000'
    end

    def msg_l
      'L:Cw/a7QkSGBgoAMwACw/DcwkSGBgoAM8ACw/DgAkSGBgoAM4A'
    end

    def msg_n
      'N:Aw4VzExFUTAwMTUzNDD/'
    end

    def close
      puts "\nClosing server ..."
      @server.close
    end
  end
end

PORT = 2000

server = MaxCube::SampleServer.new(PORT)
server.run
