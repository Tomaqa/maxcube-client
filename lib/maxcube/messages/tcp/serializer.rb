require_relative 'handler'
require 'maxcube/messages/serializer'

module MaxCube
  module Messages
    module TCP
      # Extends {Messages::Serializer} and {TCP::Handler} of routines
      # connected to TCP Cube messages serializing.
      class Serializer
        include TCP::Handler
        include Messages::Serializer

        %w[a c f l m n q s t u z].each do |f|
          require_relative 'type/' << f
          include const_get('Message' << f.upcase)
        end

        # Known message types in the direction client -> Cube.
        MSG_TYPES = %w[u i s m n x g q e d B G J P O V W a r t l c v f z].freeze

        # Generates set of messages separated by +\\r\\n+.
        # Calls {#check_tcp_data}
        # and maps {#serialize_tcp_hash} on each hash.
        # @param hashes [Array<Hash>] particular message contents.
        # @return [String] raw data for a Cube.
        def serialize_tcp_hashes(hashes)
          raw_data = hashes.map(&method(:serialize_tcp_hash)).join
          check_tcp_data(raw_data)
        end

        # Serializes data from a single hash
        # into TCP Cube message with +\\r\\n+ at the end.
        # Subsequently calls {#check_tcp_hash},
        # {#serialize_hash_body}
        # and {#check_tcp_msg}.
        # @param hash [Hash] particular message contents separated into hash.
        # @return [String] output message (with +\\r\\n+).
        def serialize_tcp_hash(hash)
          check_tcp_hash(hash)
          msg = "#{@msg_type}:" << serialize_hash_body(hash, 'tcp')
          check_tcp_msg(msg) << "\r\n"
        end
      end
    end
  end
end
