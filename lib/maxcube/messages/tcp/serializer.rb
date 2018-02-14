require_relative 'handler'
require 'maxcube/messages/serializer'

module MaxCube
  module Messages
    module TCP
      class Serializer
        include Handler
        include Messages::Serializer

        %w[a c f l m n q s t u z].each { |f| require_relative 'type/' << f }

        MSG_TYPES = %w[u i s m n x g q e d B G J P O V W a r t l c v f z].freeze

        include MessageA
        include MessageC
        include MessageF
        include MessageL
        include MessageM
        include MessageN
        include MessageQ
        include MessageS
        include MessageT
        include MessageU
        include MessageZ

        # Send set of messages separated by "\r\n"
        # @param [Array<Hash>] particular message contents
        # @return [String] raw data for a Cube
        def serialize_tcp_hashes(hashes)
          raw_data = hashes.map(&method(:serialize_tcp_hash)).join
          check_tcp_data(raw_data)
        end

        # Serialize data from hash into message with "\r\n" at the end
        # @param [Hash, #read] particular human readable message parts
        #                      (it is assumed to contain valid data)
        # @return [String] single message data with "\r\n" at the end
        def serialize_tcp_hash(hash)
          check_tcp_hash(hash)
          msg = "#{@msg_type}:" << serialize_hash_body(hash, 'tcp')
          check_tcp_msg(msg) << "\r\n"
        end
      end
    end
  end
end
