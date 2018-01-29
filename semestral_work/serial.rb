require 'base64'

# Structure of message:
# * Starts with single letter followed by ':'
# * Ends with '\r\n'
# Example (unencoded):
# X:message\r\n
class MaxCube::Receive
  RECV_MSG_TYPES = %w[ H ]
  SEND_MSG_TYPES = RECV_MSG_TYPES.map(&:swapcase)

  # Process set of messages - byte stream separated by '\r\n'
  # Returns array of hashes
  def process(data)
    data.split("\r\n").map(:&parse).to_a
  end

  # Parse single message already without '\r\n'
  # Separates particular data into hash
  # TODO: how to correctly deal with invalid messages?
  def parse(msg)
    raise InvalidMessage unless valid(msg)
    type, body = msg.split(':')
    type.downcase!
    send("parse_#{type}", body)
  end

  # Check single message validity, which is already without '\r\n'
  def valid(msg)
    msg =~ /^[[:alpha:]]:[^:]*$/ &&
      MSG_TYPES.includes? msg.first
  end

  private

  def valid_lengths(values, lengths)
    # values.each_with_index.all? { |v, i| v.length == lengths[i] }
    values.each_with_index.all? { |v, i| !lengths[i] || v.length == lengths[i] }
  end

  def parse_h(body)
    values = body.split(',')
    # lengths = [ 10, 6, 4, 8, 8, 2, 2, 6, 4, 2, 4 ]
    lengths = [ 10, 6, 4 ]
    raise InvalidMessage unless valid_lengths(values, lengths)
    keys = %i[
      serial_number
      rf_address
      firmware_version
      # unknown
      # http_id
      # duty_cycle
      # free_memory_slots
      # cube_date
      # cube_time
      # state_cube_time
      # ntp_counter
    ]
    keys.zip(values).to_h
  end

  def encode(data)
    Base64.encode64(data)
  end

  def decode(data)
    Base64.decode64(data)
  end

end
