require 'base64'
require 'stringio'

require 'maxcube/messages'

module MaxCube
  module Messages
    # This module provides methods that handles with messages
    # regardless whether it is for parse or serialize purposes.
    # It mostly contains methods that validates (returns Boolean)
    # or checks (raises exception on failure) some part of message.
    module Handler
      include Messages

      # Format characters to String#unpack and Array#pack,
      # for purposes to convert binary string to integer.
      # Elements are sorted by integer size in bytes.
      PACK_FORMAT = %w[x C n N N].freeze

      # Checks whether raw data string is +String+.
      # @param raw_data input raw data string.
      # @return [Boolean] +true+ if argument is +String+, +false+ otherwise.
      def valid_data_type(raw_data)
        raw_data.is_a?(String)
      end

      # Checks whether {#valid_data_type} is +true+.
      # If not, exception is raised.
      # @return [String] input raw data string.
      # @raise [TypeError] if argument is _not_ valid.
      def check_data_type(raw_data)
        raise TypeError unless valid_data_type(raw_data)
        raw_data
      end

      # Validates whether message type character is valid.
      # Calls {#maybe_check_valid_msg_type}.
      # @param msg_type [String] input message type character.
      # @return [Boolean] +true+ if argument is valid message type.
      def valid_msg_type(msg_type)
        maybe_check_valid_msg_type(msg_type, false)
      end

      # Checks whether message type character is valid.
      # Calls {#maybe_check_valid_msg_type}.
      # If argument is valid, it assigns the message type to internal variable.
      # @param msg_type [String] input message type character.
      # @return [String] message type character assigned to internal variable.
      # @raise [InvalidMessageType] if validation fails.
      def check_msg_type(msg_type)
        maybe_check_valid_msg_type(msg_type, true)
        @msg_type
      end

      # Validates whether message type character of message is valid.
      # Calls {#valid_msg_type} and #msg_msg_type
      # (this method depends on conrete end-class).
      # @param msg [String] input message.
      def valid_msg_msg_type(msg)
        valid_msg_type(msg_msg_type(msg))
      end

      # Checks whether message type character of message is valid.
      # Calls {#check_msg_type} and #msg_msg_type
      # (this method depends on conrete end-class).
      # If argument is valid, it assigns the message type to internal variable.
      # @param msg [String] input message.
      def check_msg_msg_type(msg)
        check_msg_type(msg_msg_type(msg))
      end

      # Validates whether whole message is valid
      # from general point of view, independently of parser/sserializer.
      # Currently, it just calls {#valid_msg_msg_type}.
      # @param msg [String] input message.
      def valid_msg(msg)
        valid_msg_msg_type(msg)
      end

      # As {#valid_msg}, but raises exception if message is invalid.
      # Currently, it just calls {#check_msg_msg_type}.
      # @param msg [String] input message.
      def check_msg(msg)
        check_msg_msg_type(msg)
      end

      # Validates whether message type character in hash is valid.
      # Calls {#valid_msg_type}.
      # @param hash [Hash] input hash.
      def valid_hash_msg_type(hash)
        valid_msg_type(hash[:type])
      end

      # Checks whether message type character in hash is valid.
      # Calls {#check_msg_type}.
      # If argument is valid, it assigns the message type to internal variable.
      # @param hash [Hash] input hash.
      def check_hash_msg_type(hash)
        check_msg_type(hash[:type])
      end

      # Returns hash keys that are related to given message type.
      # Each hash with a message type should contain these keys.
      # Calls {#msg_type_which_hash_keys}.
      # @param msg_type [String] message type that is being parsed/serialized.
      def msg_type_hash_keys(msg_type)
        msg_type_which_hash_keys(msg_type, false)
      end

      # Returns optional hash keys that are related to given message type.
      # Calls {#msg_type_which_hash_keys}.
      # @param msg_type [String] message type that is being parsed/serialized.
      def msg_type_hash_opt_keys(msg_type)
        msg_type_which_hash_keys(msg_type, true)
      end

      # Validates if given hash contain valid keys,
      # depending on its message type
      # (according to {#msg_type_which_hash_keys}).
      # Calls {#maybe_check_valid_hash_keys}.
      # @param hash [Hash] input hash.
      def valid_hash_keys(hash)
        maybe_check_valid_hash_keys(hash, false)
      end

      # As {#valid_hash_keys}, but raises exception if hash is _not_ valid.
      # Calls {#maybe_check_valid_hash_keys}.
      # @param hash [Hash] input hash.
      # @return [Hash] input hash.
      def check_hash_keys(hash)
        maybe_check_valid_hash_keys(hash, true)
        hash
      end

      # Validates if values of given hash satisfies basic conditions
      # for all hashes being used with messages.
      # @param hash [Hash] input hash.
      # @return [Boolean] +true+ if hash values are valid
      #   (from general point of view).
      def valid_hash_values(hash)
        hash.none? { |_, v| v.nil? }
      end

      # As {#valid_hash_values}, but raises exception
      # if hash values are _not_ valid.
      # @param hash [Hash] input hash.
      # @return [Hash] input hash.
      # @raise [InvalidMessageBody] if hash values are _not_ valid.
      def check_hash_values(hash)
        return hash if valid_hash_values(hash)
        hash = hash.dup
        hash.delete(:type)
        raise InvalidMessageBody
          .new(@msg_type, "invalid hash values: #{hash}")
      end

      # Validates if given hash satisfies basic conditions
      # for all hashes being used with messages.
      # Calls {#valid_hash_msg_type},
      # {#valid_hash_keys} and {#valid_hash_values}.
      # @param hash [Hash] input hash.
      # @return [Boolean] +true+ if hash is valid
      #   (from general point of view).
      def valid_hash(hash)
        valid_hash_msg_type(hash) &&
          valid_hash_keys(hash) &&
          valid_hash_values(hash)
      end

      # As {#valid_hash}, but raises exception if hash is _not_ valid.
      # Calls {#check_hash_msg_type},
      # {#check_hash_keys} and {#check_hash_values}.
      # @param hash [Hash] input hash.
      # @return [Hash] input hash.
      def check_hash(hash)
        check_hash_msg_type(hash)
        check_hash_keys(hash)
        check_hash_values(hash)
        hash
      end

      private

      # Gets +MSG_TYPES+ constant depending on object's end-class.
      # @return [Array<String>] +MSG_TYPES+ constant
      #   depending on object's end-class.
      def msg_types
        self.class.const_get('MSG_TYPES')
      end

      # Helper method that is called by {#valid_msg_type} or {#check_msg_type}.
      # It provides validation or check depending on input flag.
      # If argument is valid, it assigns the message type to internal variable.
      # @param msg_type [String] input message type character.
      # @param check [Boolean] whether to check (raise exception on failure).
      def maybe_check_valid_msg_type(msg_type, check)
        valid = msg_type&.length == 1 &&
                msg_types.include?(msg_type)
        return valid ? msg_type : false unless check
        @msg_type = msg_type
        raise InvalidMessageType.new(@msg_type) unless valid
      end

      # Checks whether given +args+
      # satisfy lengths specified in input +lengths+.
      # Missing positions in +lengths+ means
      # that no requirement is demanded at that index.
      # @param lengths [Array<Integer>] required lenghts of arguments.
      # @param args [Array<#length>] arguments to be validated.
      # @return [Boolean] +true+ if lengths of 'all' +args+
      #   fits to input +lengths+;
      #   +false+ otherwise, or if any +arg+ is +nil+,
      #   or if size of +lengths+ is higher than number of +args+.
      def valid_msg_part_lengths(lengths, *args)
        return false if args.any?(&:nil?) ||
                        args.length < lengths.length
        args.each_with_index.all? do |v, i|
          !lengths[i] || v.length == lengths[i]
        end
      end

      # As {#valid_msg_part_lengths}, but raises exception on failure.
      # @return [Array] +args+ if +lengths+ are satisfied.
      # @raise [InvalidMessageBody] if +lengths+ are _not_ satisfied.
      def check_msg_part_lengths(lengths, *args)
        return args if valid_msg_part_lengths(lengths, *args)
        raise InvalidMessageBody
          .new(@msg_type,
               "invalid lengths of message parts #{args}" \
               " (lengths should be: #{lengths})")
      end

      # Helper method that is called
      # by {#msg_type_hash_keys} or {#msg_type_hash_opt_keys}.
      # It accesses +KEYS+ or +OPT_KEYS+ (depending on input flag)
      # from object's concrete end-class.
      # @param msg_type [String] message type that is being parsed/serialized.
      # @param optional [Boolean] whether to return optional or mandatory keys.
      # @return [Array<Symbol>] mandatory or optional hash keys,
      #   depending on +optional+, related to message type.
      #   If constant is not found, empty array is returned.
      def msg_type_which_hash_keys(msg_type, optional = false)
        str = "Message#{msg_type.upcase}::" + (optional ? 'OPT_KEYS' : 'KEYS')
        self.class.const_defined?(str) ? self.class.const_get(str) : []
      end

      # Helper method that is called
      # by {#valid_hash_keys} or {#check_hash_keys}.
      # It validates/checks whether given hash contain
      # all mandatory keys ({#msg_type_hash_keys})
      # and not other than optional keys ({#msg_type_hash_opt_keys}).
      # @param hash [Hash] input hash.
      # @param check [Boolean] whether to check (raise exception on failure).
      # @return [Boolean] +true+ or +false+ for valid/invalid hash keys
      #   if +check+ is +false+.
      # @raise [InvalidMessageBody] if +check+ is +true+
      #   and hash keys are invalid.
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

      # Encodes input binary data to only printable characters
      # using Base64#strict_encode64.
      # @param data [String] input raw data string.
      # @return [String] Base64-encoded string.
      def encode(data)
        Base64.strict_encode64(data)
      end

      # Decodes input data with only printable characters
      # to binary data using Base64#decode64.
      # @param data [String] input Base64-encoded string.
      # @return [String] raw data string.
      def decode(data)
        Base64.decode64(data)
      end
    end
  end
end
