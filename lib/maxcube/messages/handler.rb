require 'base64'
require 'stringio'

require 'maxcube/messages'

module MaxCube
  module Messages
    module Handler
      include Messages

      def valid_data_type(raw_data)
        raw_data.is_a?(String)
      end

      def check_data_type(raw_data)
        raise TypeError unless valid_data_type(raw_data)
        raw_data
      end

      def valid_msg_type(msg_type)
        maybe_check_valid_msg_type(msg_type, false)
      end

      def check_msg_type(msg_type)
        maybe_check_valid_msg_type(msg_type, true)
        @msg_type
      end

      def valid_msg_msg_type(msg)
        valid_msg_type(msg_msg_type(msg))
      end

      def check_msg_msg_type(msg)
        check_msg_type(msg_msg_type(msg))
      end

      def valid_msg(msg)
        valid_msg_msg_type(msg)
      end

      def check_msg(msg)
        check_msg_msg_type(msg)
      end

      def valid_hash_msg_type(hash)
        valid_msg_type(hash[:type])
      end

      def check_hash_msg_type(hash)
        msg_type = hash[:type]
        check_msg_type(msg_type)
        msg_type
      end

      def msg_type_hash_keys(msg_type)
        msg_type_which_hash_keys(msg_type, false)
      end

      def msg_type_hash_opt_keys(msg_type)
        msg_type_which_hash_keys(msg_type, true)
      end

      def valid_hash_keys(hash)
        maybe_check_valid_hash_keys(hash, false)
      end

      def check_hash_keys(hash)
        maybe_check_valid_hash_keys(hash, true)
        hash
      end

      def valid_hash_values(hash)
        hash.none? { |_, v| v.nil? }
      end

      def check_hash_values(hash)
        return hash if valid_hash_values(hash)
        hash = hash.dup
        hash.delete(:type)
        raise InvalidMessageBody
          .new(@msg_type, "invalid hash values: #{hash}")
      end

      def valid_hash(hash)
        valid_hash_msg_type(hash) &&
          valid_hash_keys(hash) &&
          valid_hash_values(hash)
      end

      def check_hash(hash)
        check_hash_msg_type(hash)
        check_hash_keys(hash)
        check_hash_values(hash)
        hash
      end

      private

      def msg_types
        self.class.const_get('MSG_TYPES')
      end

      def maybe_check_valid_msg_type(msg_type, check)
        valid = msg_type&.length == 1 &&
                msg_types.include?(msg_type)
        return valid ? msg_type : false unless check
        @msg_type = msg_type
        raise InvalidMessageType.new(@msg_type) unless valid
      end

      def valid_msg_part_lengths(lengths, *args)
        return false if args.any?(&:nil?) ||
                        args.length < lengths.length
        args.each_with_index.all? do |v, i|
          !lengths[i] || v.length == lengths[i]
        end
      end

      def check_msg_part_lengths(lengths, *args)
        return if valid_msg_part_lengths(lengths, *args)
        raise InvalidMessageBody
          .new(@msg_type,
               "invalid lengths of message parts #{args}" \
               " (lengths should be: #{lengths})")
      end

      def msg_type_which_hash_keys(msg_type, optional = false)
        str = "Message#{msg_type.upcase}::" + (optional ? 'OPT_KEYS' : 'KEYS')
        self.class.const_defined?(str) ? self.class.const_get(str) : []
      end

      def maybe_check_valid_hash_keys(hash, check)
        keys = msg_type_hash_keys(@msg_type).dup
        opt_keys = msg_type_hash_opt_keys(@msg_type)

        hash_keys = hash.keys - opt_keys - [:type]

        valid = hash_keys.sort == keys.sort
        return valid if !check || valid
        raise InvalidMessageBody
          .new(@msg_type, "invalid hash keys: #{hash_keys} " \
               "(should be: #{keys})")
      end

      def encode(data)
        Base64.strict_encode64(data)
      end

      def decode(data)
        Base64.decode64(data)
      end
    end
  end
end
