require 'maxcube/network/udp'

module MaxCube
  module Network
    module UDP
      class SampleSocket
        def initialize(port = PORT)
          @port = port
          @socket = UDPSocket.new
          @socket.bind('0.0.0.0', port)

          @parser = Messages::UDP::Parser.new
          @serializer = Messages::UDP::Serializer.new
        end

        def run
          puts "Starting socket on port #{@port} ...\n\n"
          loop do
            msg, addr = @socket.recvfrom(1024)
            port = addr[1]
            ipaddr = addr[3]
            puts "Income message from #{ipaddr}:#{port}: '#{msg}'"
            cmd(msg, ipaddr, port) if @serializer.valid_udp_msg(msg)
          end
        rescue Interrupt
          close
        end

        def send_msg(msg, addr, port)
          @socket.send(msg, 0, addr, port)
        end

        private

        def cmd(msg, addr, port)
          type = @serializer.check_msg_msg_type(msg)
          puts "Message type: #{type}"

          method_str = "msg_#{type.downcase}"
          return unless respond_to?(method_str, true)
          send_msg(send(method_str), addr, port)
        end

        def msg_i
          "eQ3MaxApKEQ0523864>I\x00\x09\x7f\x2c\x01\x13"
        end

        def msg_n
          'eQ3MaxApKEQ0565026>N' \
          "\xc0\xa8\x00\xde\xc0\xa8\x00\x01\xff\xff\x00\x00" \
          "\xc0\xa8\x00\x01\xc0\xa8\x00\x01"
        end

        def msg_h
          "eQ3MaxApKEQ0565026>h\x00Pmax.eq-3.de,/cube"
        end

        def close
          puts "\nClosing socket ..."
          @socket.close
        end
      end
    end
  end
end
