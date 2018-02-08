require 'socket'

module MaxCube
  class SampleServer
    def initialize(port)
      @server = TCPServer.new(port)
    end

    def run
      puts "Starting server ...\n\n"
      loop do
        Thread.start(@server.accept) do |client|
          puts "Accepting #{client.addr[3]}:#{client.addr[1]} ..."
          send_msg(client, msg_h)
          send_msg(client, msg_l)
          loop do
            msg = client.gets
            puts msg
            if !msg || msg == "q:\r\n"
              puts "Closing #{client.addr[3]}:#{client.addr[1]} ..."
              client.close
              Thread.stop
            end
          end
        end
      end
    rescue Interrupt
      close
    end

    def send_msg(client, msg)
      client.puts(msg)
    end

    private

    def msg_h
      "H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\n"
    end

    def msg_l
      "L:Cw/a7QkSGBgoAMwACw/DcwkSGBgoAM8ACw/DgAkSGBgoAM4A\r\n"
    end

    def close
      puts "\nClosing server ..."
      @server.close
    end
  end
end

server = MaxCube::SampleServer.new(2000)
server.run
