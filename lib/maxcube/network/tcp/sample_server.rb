require 'maxcube/network/tcp'

module MaxCube
  module Network
    module TCP
      class SampleServer
        def initialize(port = PORT)
          @port = port
          @server = TCPServer.new(port)

          @ntp_servers = %w[nl.pool.ntp.org ntp.homematic.com]
        end

        def run
          puts "Starting server on port #{@port} ...\n\n"
          loop do
            Thread.start(@server.accept) do |client|
              puts "Accepting #{client.addr[3]}:#{client.addr[1]} ..."
              send_msg(client, msg_h)
              send_msg(client, msg_l)
              loop do
                run_loop(client)
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

        def run_loop(client)
          msgs = client.gets
          raise IOError unless msgs
          msgs.split("\r\n").each do |msg|
            raise IOError if msg == 'q:'
            puts "Income message: '#{msg}'"
            cmd(client, msg)
          end
        rescue IOError
          puts "Closing #{client.addr[3]}:#{client.addr[1]} ..."
          client.close
          Thread.stop
        end

        def cmd(client, msg)
          type, body = msg.split(':')
          method_str = "msg_#{type}"
          return unless respond_to?(method_str, true)
          send_msg(client, method(method_str).call(body))
        end

        def msg_a(_body = nil)
          'A:'
        end

        alias msg_t msg_a
        alias msg_z msg_a

        def msg_c(_body = nil)
          'C:01b491,EQG0kQUAEg9KRVEwMzA1MjA1'
        end

        def msg_h(_body = nil)
          'H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000'
        end

        def msg_l(_body = nil)
          'L:Cw/a7QkSGBgoAMwACw/DcwkSGBgoAM8ACw/DgAkSGBgoAM4A'
        end

        def msg_n(_body = nil)
          'N:Aw4VzExFUTAwMTUzNDD/'
        end

        def msg_f(body = nil)
          @ntp_servers = body.split(',') if body
          'F:' + @ntp_servers.join(',')
        end

        def msg_s(_body = nil)
          'S:00,0,31'
        end

        def close
          puts "\nClosing server ..."
          @server.close
        end
      end
    end
  end
end
