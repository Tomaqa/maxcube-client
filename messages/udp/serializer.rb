require_relative 'handler'
require_relative '../serializer'

# %w[i n h].each { |f| require_relative 'type/' << f }

module MaxCube
  module Messages
    module UDP
      class Serializer
        include Handler
        include Messages::Serializer

        MSG_TYPES = %w[I N h c R].freeze

        # include MessageA

        MSG_PREFIX = (UDP::MSG_PREFIX + "*\x00").freeze

        def serialize_udp_hash(hash)
          type = hash[:type]
          serial_number = hash[:serial_number] || '*' * 10
          MSG_PREFIX + serial_number << type
        end
      end
    end
  end
end
