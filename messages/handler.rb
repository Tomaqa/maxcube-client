require 'base64'
require 'stringio'

require_relative 'messages'

module MaxCube
  module Messages
    module Handler
      class InvalidMessage < RuntimeError; end

      class InvalidMessageLength < InvalidMessage
        def initialize(info = 'invalid message length')
          super
        end
      end

      class InvalidMessageType < InvalidMessage
        def initialize(msg_type, info = 'invalid message type')
          super("#{info}: #{msg_type}")
        end
      end

      class InvalidMessageFormat < InvalidMessage
        def initialize(info = 'invalid format')
          super
        end
      end

      class InvalidMessageBody < InvalidMessage
        def initialize(msg_type, info = 'invalid format')
          super("message type #{msg_type}: #{info}")
        end
      end

      def valid_data_type(raw_data)
        raw_data.is_a?(String)
      end

      def check_data_type(raw_data)
        raise TypeError unless valid_data_type(raw_data)
        raw_data
      end

      private

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

      def encode(data)
        Base64.strict_encode64(data)
      end

      def decode(data)
        Base64.decode64(data)
      end
    end
  end
end
