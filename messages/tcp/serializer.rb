require_relative 'handler'
require_relative '../serializer'

%w[a c f l m n q s t u z].each { |f| require_relative 'type/' << f }

module MaxCube
  module Messages
    module TCP
      class Serializer
        include Handler
        include Messages::Serializer

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

        def tcp_serial_msg_type_keys(msg_type)
          tcp_serial_msg_type_which_keys(msg_type, false)
        end

        def tcp_serial_msg_type_optional_keys(msg_type)
          tcp_serial_msg_type_which_keys(msg_type, true)
        end

        def valid_tcp_serial_msg_type(hash)
          maybe_check_valid_tcp_serial_msg_type(hash, false)
        end

        def check_tcp_serial_msg_type(hash)
          maybe_check_valid_tcp_serial_msg_type(hash, true)
        end

        def valid_tcp_serial_hash_keys(hash)
          maybe_check_tcp_serial_hash_keys(hash, false)
        end

        def check_tcp_serial_hash_keys(hash)
          maybe_check_tcp_serial_hash_keys(hash, true)
        end

        def valid_tcp_serial_hash(hash)
          valid_tcp_serial_msg_type(hash) &&
            valid_tcp_serial_hash_keys(hash) &&
            valid_serial_hash_values(hash)
        end

        def check_tcp_serial_hash(hash)
          check_tcp_serial_msg_type(hash)
          check_tcp_serial_hash_keys(hash)
          check_serial_hash_values(hash)
        end

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
          check_tcp_serial_hash(hash)
          msg = "#{@msg_type}:"

          method_str = "serialize_tcp_#{@msg_type.downcase}"
          unless respond_to?(method_str, true)
            raise InvalidMessageType
              .new(@msg_type, 'message type is not implemented yet')
          end
          msg << send(method_str, hash)
          check_tcp_msg(msg) << "\r\n"
        end

        private

        def tcp_serial_msg_type_which_keys(msg_type, optional = false)
          str = "Message#{msg_type.upcase}::" + (optional ? 'OPT_KEYS' : 'KEYS')
          self.class.const_defined?(str) ? self.class.const_get(str) : []
        end

        def maybe_check_valid_tcp_serial_msg_type(hash, check)
          msg_type = hash[:type]
          valid = msg_type&.length == 1 &&
                  MSG_TYPES.include?(msg_type)
          return valid ? msg_type : false unless check
          @msg_type = msg_type
          raise InvalidMessageType.new(@msg_type) unless valid
        end

        def maybe_check_tcp_serial_hash_keys(hash, check)
          keys = tcp_serial_msg_type_keys(@msg_type).dup
          opt_keys = tcp_serial_msg_type_optional_keys(@msg_type)

          hash_keys = hash.keys - opt_keys - [:type]

          valid = hash_keys.sort == keys.sort
          return valid if !check || valid
          raise InvalidMessageBody
            .new(@msg_type, "invalid hash keys: #{hash_keys} " \
                 "(should be: #{keys})")
        end
      end
    end
  end
end
