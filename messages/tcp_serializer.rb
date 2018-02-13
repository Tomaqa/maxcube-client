module MaxCube
  class Messages
    module Serializer
      module TCP
        MSG_TYPES = %w[u i s m n x g q e d B G J P O V W a r t l c v f z].freeze

        def serialize_tcp_msg_type_keys(msg_type)
          serialize_tcp_msg_type_which_keys(msg_type, false)
        end
        alias serialize_msg_type_keys serialize_tcp_msg_type_keys

        def serialize_tcp_msg_type_optional_keys(msg_type)
          serialize_tcp_msg_type_which_keys(msg_type, true)
        end
        alias serialize_msg_type_optional_keys serialize_tcp_msg_type_optional_keys

        def valid_tcp_serialize_msg_type(hash)
          maybe_check_valid_tcp_serialize_msg_type(hash, false)
        end
        alias valid_serialize_msg_type valid_tcp_serialize_msg_type

        def check_tcp_serialize_msg_type(hash)
          maybe_check_valid_tcp_serialize_msg_type(hash, true)
        end

        def valid_tcp_serialize_hash_keys(hash)
          maybe_check_tcp_serialize_hash_keys(hash, false)
        end
        alias valid_serialize_hash_keys valid_tcp_serialize_hash_keys

        def check_tcp_serialize_hash_keys(hash)
          maybe_check_tcp_serialize_hash_keys(hash, true)
        end

        def valid_tcp_serialize_hash_values(hash)
          hash.none? { |_, v| v.nil? }
        end
        alias valid_serialize_hash_values valid_tcp_serialize_hash_values

        def check_tcp_serialize_hash_values(hash)
          return if valid_tcp_serialize_hash_values(hash)
          hash = hash.dup
          hash.delete(:type)
          raise InvalidMessageBody
            .new(@msg_type, "invalid hash values: #{hash}")
        end

        def valid_tcp_serialize_hash(hash)
          valid_tcp_serialize_msg_type(hash) &&
            valid_tcp_serialize_hash_keys(hash) &&
            valid_tcp_serialize_hash_values(hash)
        end
        alias valid_serialize_hash valid_tcp_serialize_hash

        def check_tcp_serialize_hash(hash)
          check_tcp_serialize_msg_type(hash)
          check_tcp_serialize_hash_keys(hash)
          check_tcp_serialize_hash_values(hash)
        end

        def serialize(*args, esize: 0, size: 0, ocount: 0)
          return args.join if size.zero? && esize.zero?

          ocount, subcount, subsize = serialize_bounds(args,
                                                       esize: esize,
                                                       size: size,
                                                       ocount: ocount)
          str = ''
          args.reverse!
          ocount.times do
            str << args.pop while args.last.is_a?(String)
            substr = args.pop(subcount).pack(PACK_FORMAT[subsize])
            substr = substr[1..-1] if subsize == 3
            str << substr
          end
          str << args.pop until args.empty?

          str
        end

        def write(*args, esize: 0, size: 0, ocount: 0)
          @io.write(serialize(*args, esize: esize, size: size, ocount: ocount))
        end

        # Send set of messages separated by "\r\n"
        # @param [Array<Hash>] particular message contents
        # @return [String] raw data for a Cube
        def serialize_tcp_data(hashes)
          raw_data = hashes.map(&method(:serialize_hash)).join
          check_tcp_data(raw_data)
        end
        alias serialize_data serialize_tcp_data

        # Serialize data from hash into message with "\r\n" at the end
        # @param [Hash, #read] particular human readable message parts
        #                      (it is assumed to contain valid data)
        # @return [String] single message data with "\r\n" at the end
        def serialize_tcp_hash(hash)
          check_tcp_serialize_hash(hash)
          msg = "#{@msg_type}:"

          method_str = "serialize_#{@msg_type.downcase}"
          unless respond_to?(method_str, true)
            raise InvalidMessageType
              .new(@msg_type, 'message type is not implemented yet')
          end
          msg << send(method_str, hash)
          check_tcp_msg(msg) << "\r\n"
        end
        alias serialize_hash serialize_tcp_hash

        require_relative 'a_message'
        require_relative 'c_message'
        require_relative 'f_message'
        require_relative 'l_message'
        require_relative 'm_message'
        require_relative 'n_message'
        require_relative 'q_message'
        require_relative 's_message'
        require_relative 't_message'
        require_relative 'u_message'
        require_relative 'z_message'

        private

        def serialize_tcp_msg_type_which_keys(msg_type, optional = false)
          str = "Message#{msg_type.upcase}::" + (optional ? 'OPT_KEYS' : 'KEYS')
          self.class.const_defined?(str) ? self.class.const_get(str) : []
        end

        def maybe_check_valid_tcp_serialize_msg_type(hash, check)
          msg_type = hash[:type]
          valid = msg_type&.length == 1 &&
                  MSG_TYPES.include?(msg_type)
          return valid ? msg_type : false unless check
          @msg_type = msg_type
          raise InvalidMessageType.new(@msg_type) unless valid
        end

        def maybe_check_tcp_serialize_hash_keys(hash, check)
          keys = serialize_msg_type_keys(@msg_type).dup
          opt_keys = serialize_msg_type_optional_keys(@msg_type)

          hash_keys = hash.keys - opt_keys - [:type]

          valid = hash_keys.sort == keys.sort
          return valid if !check || valid
          raise InvalidMessageBody
            .new(@msg_type, "invalid hash keys: #{hash_keys} " \
                 "(should be: #{keys})")
        end

        def serialize_bounds(args, esize: 0, size: 0, ocount: 0)
          icount = args.size - args.count { |a| a.is_a?(String) }
          return 0 if icount.zero?
          if esize.zero?
            ocount = icount if ocount.zero?
            subsize = size / ocount
          else
            size = icount * esize
            ocount = size / esize
            subsize = esize
          end
          subcount = icount / ocount

          [ocount, subcount, subsize]
        end
      end
    end
  end
end