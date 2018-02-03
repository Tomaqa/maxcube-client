require 'base64'
require 'date'
require_relative '../messages'
require_relative 'spec_helper'

describe 'MessageReceiver' do
  subject(:recv) { MaxCube::MessageReceiver.new }

  # Proper message examples:
  # A:\r\n
  # C:03f25d,7QPyXQATAQBKRVEwNTQ0OTIzAAsABEAAAAAAAAAAAPIA==\r\n
  # H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\n
  # L:Cw/a7QkSGBgoAMwACw/DcwkSGBgoAM8ACw/DgAkSGBgoAM4A\r\n

  describe 'invalid message' do
    context 'empty message' do
      let(:inputs) do
        [
          '',
          "\r\n",
          "\r\n\r\n",
        ]
      end
      it 'returns empty array' do
        inputs.each do |i|
          expect(recv.recv_data(i)).to eq([])
        end
      end
    end

    # context 'invalid type' do
    #   let(:inputs) do
    #     [
    #       nil,
    #       0,
    #       1,
    #       1.5,
    #       /abc/,
    #       Object.new,
    #       [],
    #       {},
    #     ]
    #   end
    #   it 'raises proper exception' do
    #     inputs.each do |inp|
    #       expect { recv.recv_data(inp) }.to raise_error TypeError
    #     end
    #   end
    # end

    context 'invalid format' do
      context 'of single message' do
        let(:msgs) do
          [
            '::',
            'H::',
            'H:X:',
            'A:A:',
            'HX:',
            'HX:A',
            'HX:A:',
            '1:',
          ]
        end
        it 'raises proper exception and #valid_recv_msg is falsey' do
          msgs.each do |m|
            expect { recv.recv_msg(m) }.to raise_error MaxCube::MessageHandler::InvalidMessageFormat
            expect(recv.valid_recv_msg(m)).to be_falsey
          end
        end
        it 'raises proper exception when passed as raw data' do
          msgs.each do |m|
            expect { recv.recv_data(m) }.to raise_error MaxCube::MessageHandler::InvalidMessageFormat
          end
        end
      end

      context 'of raw data' do
        let(:data) do
          [
            'A:\r\nA:',
            'A:\nA:',
            'A:\rA:',
            'A:\r\nA:\r\n',
            "A:A:\r\n",
            "A:\r\nA:\r\naX:",
            "A:\r\nA:\r\naX:\r\n",
            "H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\nA:\r\nA:\r\naX:",
            "A:\r\nH:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\nA:\r\naX:",
            "A:\nH:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\nA:\r\naX:",
          ]
        end
        it 'raises proper exception' do
          data.each do |d|
            expect { recv.recv_data(d) }.to raise_error MaxCube::MessageHandler::InvalidMessageFormat
          end
        end
      end
    end

    context 'invalid message type' do
      let(:msgs) do
        [
          'X:',
          'h:',
          'u:',
          'x:',
          'l:',
        ]
      end
      it 'raises proper exception and #valid_recv_msg_type is falsey' do
        msgs.each do |m|
          expect { recv.recv_data(m) }.to raise_error MaxCube::MessageHandler::InvalidMessageType
          expect(recv.valid_recv_msg_type(m)).to be_falsey
        end
      end
    end

    context 'invalid message body in general' do
      let(:msgs) do
        [
          'H:',
          'M:',
        ]
      end
      it 'raises proper exception' do
        msgs.each do |m|
          expect { recv.recv_data(m) }.to raise_error MaxCube::MessageHandler::InvalidMessageBody
        end
      end
    end

    context 'invalid message length' do
      let(:msgs) do
        [
          'A',
          ':',
          'A:' + 'x' * MaxCube::MessageHandler::MSG_MAX_LEN,
        ]
      end
      it 'raises proper exception and #valid_msg_length is falsey' do
        msgs.each do |m|
          expect { recv.recv_msg(m) }.to raise_error MaxCube::MessageHandler::InvalidMessageLength
          expect(recv.valid_msg_length(m)).to be_falsey
        end
      end
    end
  end

  describe 'valid data' do
    let(:data) do
      [
        "A:\r\nH:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\n",
        "A:abcde\r\nA:\r\n",
        "H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\n"\
        "H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\n",
        "A:\r\nA:\r\n"\
        "H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\n"\
        "A:\r\n"\
        "M:00,01,VgIEAQNCYWQK7WkCBEJ1cm8K8wADCldvaG56aW1tZXIK8wwEDFNjaGxhZnppbW1lcgr"\
        "1QAUCCu1pS0VRMDM3ODA0MAZIVCBCYWQBAgrzAEtFUTAzNzk1NDQHSFQgQnVybwICCvMMS0VRMD"\
        "M3OTU1NhlIVCBXb2huemltbWVyIEJhbGtvbnNlaXRlAwIK83lLRVEwMzc5NjY1GkhUIFdvaG56a"\
        "W1tZXIgRmVuc3RlcnNlaXRlAwIK9UBLRVEwMzgwMTIwD0hUIFNjaGxhZnppbW1lcgQB\r\n"\
        "A:\r\n",
      ]
    end
    let(:res) do
      [
        %w[A H],
        %w[A A],
        %w[H H],
        %w[A A H A M A],
      ]
    end
    it 'returns array of hashes with proper message types' do
      data.each_with_index do |d, i|
        ary = recv.recv_data(d)
        expect(ary).to be_an(Array).and all(be_a(Hash))
        ary.each_with_index do |h, j|
          expect(h).to include(:type)
          expect(h[:type]).to eq(res[i][j])
        end
      end
    end
  end

  describe 'concrete message types' do
    describe 'A message' do
      let(:msgs) do
        [
          'A:',
          'A:acknowledgement!',
          'A:\r\n',
          'A:1234abcd',
        ]
      end
      it 'ignores any content of message' do
        msgs.each do |m|
          expect(recv.recv_msg(m)).to eq({ type: 'A' })
        end
      end
    end

    # C:03f25d,7QPyXQATAQBKRVEwNTQ0OTIzAAsABEAAAAAAAAAAAPIA==
    describe 'C message' do
      context 'invalid message body' do
        let(:msgs) do
          [
          ]
        end
        it 'raises proper exception' do
          msgs.each do |m|
            expect{ recv.recv_msg(m) }.to raise_error MaxCube::MessageHandler::InvalidMessageBody
          end
        end
      end

      context 'valid message body' do
        let(:msgs) do
          [
            # 'C:03f25d,7QPyXQATAQBKRVEwNTQ0OTIzAAsABEAAAAAAAAAAAPIA==',
            # radiator thermostat data
            'C:06c961,' + Base64.strict_encode64("\xd2\x06\xc9\x41\x01\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37\x36\x24\x20\x3d\x09\x07\x18\x03\xf4\x0c\xff\x00\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x06\x18\xf4"),
            # wall thermostat data
            # 'C:0a12bd,' + Base64.strict_encode64("\xce\x0a\x12\xbd\x03\x01\x10\xff\x4b\x45\x51\x30\x37\x30\x34\x37\x35\x32\x24\x20\x3d\x09\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x06\x18\xf4"),
          ]
        end
        let(:ret) do
          [
            { type: 'C' },
          ]
        end
        it 'returns proper hash' do
          msgs.each_with_index do |m, i|
            p recv.recv_msg(m)
            # expect(recv.recv_msg(m)).to eq(ret[i])
          end
        end
      end
    end

    # H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000
    describe 'H message' do
      context 'invalid message body' do
        let(:msgs) do
          [
            # invalid lengths of message parts
            'H:',
            'H:,,,,,,,,,,',
            'H:EQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000',
            'H:IKEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000',
            'H:IEQ0523864,97f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000',
            'H:IKEQ0523864,97f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000',
            'H:IEQ0523864,197f2c,113,00000000,477719c0,00,32,0d0c09,1404,03,0000',
            'H:IKEQ0523864,197f2c,113,00000000,477719c0,00,32,0d0c09,1404,03,0000',
            # invalid hex format of 3rd part
            'H:KEQ0523864,097f2c,x113,00000000,477719c0,00,32,0d0c09,1404,03,0000',
          ]
        end
        it 'raises proper exception' do
          msgs.each do |m|
            expect{ recv.recv_msg(m) }.to raise_error MaxCube::MessageHandler::InvalidMessageBody
          end
        end
      end

      context 'valid message body' do
        let(:msgs) do
          [
            'H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000',
            'H:4KFK49VMD6,c233fe,211f,00000000,477719c0,00,32,0d0c09,1404,03,0000',
          ]
        end
        let(:ret) do
          [
            { type: 'H', serial_number: 'KEQ0523864', rf_address: '097f2c', firmware_version: '0113'.to_i(16) },
            { type: 'H', serial_number: '4KFK49VMD6', rf_address: 'c233fe', firmware_version: '211f'.to_i(16) },
          ]
        end
        it 'returns proper hash' do
          msgs.each_with_index do |m, i|
            expect(recv.recv_msg(m)).to eq(ret[i])
          end
        end
      end
    end

    # L:Cw/a7QkSGBgoAMwACw/DcwkSGBgoAM8ACw/DgAkSGBgoAM4A
    describe 'L message' do
      context 'invalid message body' do
        let(:msgs) do
          [
            # unexpected EOF
            'L:' + Base64.strict_encode64("\x06\x0f\xda\xed\x09\x00"),
            'L:' + Base64.strict_encode64("\x0b\x0f\xda\xed\x09\x00\x00\x18\x18\x01\x00"),
            'L:' + Base64.strict_encode64("\x0c\x0f\xda\xed\x09\x12\x18\x18\xa8\x9d\x0b\x04"),
            # invalid length of submessage
            'L:' + Base64.strict_encode64("\x00"),
            'L:' + Base64.strict_encode64("\x03\x0f\xda\xed"),
            'L:' + Base64.strict_encode64("\x05\x0f\xda\xed\x09\x00\x00"),
            'L:' + Base64.strict_encode64("\x07\x0f\xda\xed\x09\x00\x00"),
            'L:' + Base64.strict_encode64("\x07\x0f\xda\xed\x09\x00\x00\x00"),
            'L:' + Base64.strict_encode64("\x07\x0f\xda\xed\x09\x00\x00\x18"),
            'L:' + Base64.strict_encode64("\x08\x0f\xda\xed\x09\x00\x00\x18"),
            'L:' + Base64.strict_encode64("\x0a\x0f\xda\xed\x09\x00\x00\x18\x18\x01\x00"),
            'L:' + Base64.strict_encode64("\x0a\x0f\xda\xed\x09\x00\x00\x18\x18\x01\x00\x00"),
            'L:' + Base64.strict_encode64("\x0d\x0f\xda\xed\x09\x00\x00\x18\x18\x01\x00\x00\x00\x00"),
            'L:' + Base64.strict_encode64("\x0b\x0f\xda\xed\x09\x00\x00\x18\x18\x01\x00\x00\x00"),
            # 'date_until' part is not valid date and 'actual_temperature' is currently present at offset 12
            'L:' + Base64.strict_encode64("\x0c\x0f\xda\xed\x09\x00\x00\x18\x18\x01\x00\x00\x00"),
            'L:' + Base64.strict_encode64("\x0c\x0f\xda\xed\x09\x00\x00\x18\xa8\x00\x00\x04\x24"),
            # 'date_until' part is not valid date and 'mode' is not 'auto'
            'L:' + Base64.strict_encode64("\x0b\x0f\xda\xed\x09\x00\x01\x18\xa8\x00\x00\x04"),
          ]
        end
        it 'raises proper exception' do
          msgs.each do |m|
            expect{ recv.recv_msg(m) }.to raise_error MaxCube::MessageHandler::InvalidMessageBody
          end
        end
      end

      context 'valid message body' do
        let(:msgs) do
          [
            'L:',
            'L:' + Base64.strict_encode64("\x06\x0f\xda\xed\x09\x00\x03"),
            'L:' + Base64.strict_encode64("\x0b\x0f\xda\xed\x09\x00\x00\x18\x18\x01\x00\x00"),
            'L:' + Base64.strict_encode64("\x0c\x0f\xda\xed\x09\x12\x18\x18\xa8\x9d\x0b\x04\x24"),
            'L:Cw/a7QkSGBgoAMwACw/DcwkSGBgoAM8ACw/DgAkSGBgoAM4A',
          ]
        end
        let(:ret) do
          [
            { type: 'L', devices: [] },
            { type: 'L', devices: [
                { length: 6, rf_address: "\x0f\xda\xed".b, unknown: "\x09".b,
                  flags: {
                    value: 0x0003,
                    mode: :boost,
                    dst_setting_active: false,
                    gateway_known: false,
                    panel_locked: false,
                    link_error: false,
                    low_battery: false,
                    status_initialized: false,
                    is_answer: false,
                    error: false,
                    valid_info: false,
                  },
                },
              ],
            },
            { type: 'L', devices: [
                { length: 11, rf_address: "\x0f\xda\xed".b, unknown: "\x09".b,
                  flags: {
                    value: 0x0000,
                    mode: :auto,
                    dst_setting_active: false,
                    gateway_known: false,
                    panel_locked: false,
                    link_error: false,
                    low_battery: false,
                    status_initialized: false,
                    is_answer: false,
                    error: false,
                    valid_info: false,
                  },
                  valve_position: 24, temperature: 12.0,
                  actual_temperature: 25.6,
                },
              ],
            },
            { type: 'L', devices: [
                { length: 12, rf_address: "\x0f\xda\xed".b, unknown: "\x09".b,
                  flags: {
                    value: 0x1218,
                    mode: :auto,
                    dst_setting_active: true,
                    gateway_known: true,
                    panel_locked: false,
                    link_error: false,
                    low_battery: false,
                    status_initialized: true,
                    is_answer: false,
                    error: false,
                    valid_info: true,
                  },
                  valve_position: 24, temperature: 20.0,
                  datetime_until: DateTime.new(2011, 8, 29, 2, 0),
                  actual_temperature: 29.2,
                },
              ],
            },
            { type: 'L', devices: [
                {
                  length: 11, rf_address: "\x0f\xda\xed".b, unknown: "\x09".b,
                  flags: {
                    value: 0x1218,
                    mode: :auto,
                    dst_setting_active: true,
                    gateway_known: true,
                    panel_locked: false,
                    link_error: false,
                    low_battery: false,
                    status_initialized: true,
                    is_answer: false,
                    error: false,
                    valid_info: true,
                  },
                  valve_position: 24, temperature: 20.0,
                  actual_temperature: 20.4,
                },
                {
                  length: 11, rf_address: "\x0f\xc3\x73".b, unknown: "\x09".b,
                  flags: {
                    value: 0x1218,
                    mode: :auto,
                    dst_setting_active: true,
                    gateway_known: true,
                    panel_locked: false,
                    link_error: false,
                    low_battery: false,
                    status_initialized: true,
                    is_answer: false,
                    error: false,
                    valid_info: true,
                  },
                  valve_position: 24, temperature: 20.0,
                  actual_temperature: 20.7,
                },
                {
                  length: 11, rf_address: "\x0f\xc3\x80".b, unknown: "\x09".b,
                  flags: {
                    value: 0x1218,
                    mode: :auto,
                    dst_setting_active: true,
                    gateway_known: true,
                    panel_locked: false,
                    link_error: false,
                    low_battery: false,
                    status_initialized: true,
                    is_answer: false,
                    error: false,
                    valid_info: true,
                  },
                  valve_position: 24, temperature: 20.0,
                  actual_temperature: 20.6,
                },
              ],
            },
          ]
        end
        it 'returns proper hash' do
          msgs.each_with_index do |m, i|
            expect(recv.recv_msg(m)).to eq(ret[i])
          end
        end
      end
    end

    # M:00,01,VgIEAQNCYWQK7WkCBEJ1cm8K8wADCldvaG56aW1tZXIK8wwEDFNjaGxhZnppbW1lcgr
    #   1QAUCCu1pS0VRMDM3ODA0MAZIVCBCYWQBAgrzAEtFUTAzNzk1NDQHSFQgQnVybwICCvMMS0VRMD
    #   M3OTU1NhlIVCBXb2huemltbWVyIEJhbGtvbnNlaXRlAwIK83lLRVEwMzc5NjY1GkhUIFdvaG56a
    #   W1tZXIgRmVuc3RlcnNlaXRlAwIK9UBLRVEwMzgwMTIwD0hUIFNjaGxhZnppbW1lcgQB
    describe 'M message' do
      context 'invalid message body' do
        let(:msgs) do
          [
            # message parts lengths are too short
            'M:00',
            'M:00,',
            'M:00,,',
            'M:00,01',
            'M:00,01,',
            'M:00,01,' + Base64.strict_encode64('a'),
            'M:00,01,' + Base64.strict_encode64('ab1'),
            'M:00,01,' + Base64.strict_encode64('ab01'),
            'M:00,01,' + Base64.strict_encode64('ab192XY123'),
            'M:00,01,' + Base64.strict_encode64("ab\x01"),
            'M:00,01,' + Base64.strict_encode64("ab\x00\x01"),
            'M:00,01,' + Base64.strict_encode64("ab\x01!\x02XY123"),
            'M:00,01,' + Base64.strict_encode64("ab\x01!\x02XY123\x01"),
            'M:00,01,' + Base64.strict_encode64("ab\x01!\x02XY123\x01\x04RFAserial_num\x04NAME"),
            'M:00,01,' + Base64.strict_encode64("ab\x01!\x02XY123\x02\x04RFAserial_num\x04NAME!"),
            # index/count not hex
            'M:xx,01,' + Base64.strict_encode64("ab\x00\x00"),
            'M:00,xx,' + Base64.strict_encode64("ab\x00\x00"),
            # index >= count
            'M:01,01,' + Base64.strict_encode64("ab\x00\x00"),
          ]
        end
        it 'raises proper exception' do
          msgs.each do |m|
            expect{ recv.recv_msg(m) }.to raise_error MaxCube::MessageHandler::InvalidMessageBody
          end
        end
      end

      context 'valid message body' do
        let(:msgs) do
          [
            'M:00,01,' + Base64.strict_encode64("Vx\x01!\x02XY123\x01\x04RFAserial_num\x04NAME!"),
            'M:00,01,VgIEAQNCYWQK7WkCBEJ1cm8K8wADCldvaG56aW1tZXIK8wwEDFNjaGxhZnppbW1lcgr' \
              '1QAUCCu1pS0VRMDM3ODA0MAZIVCBCYWQBAgrzAEtFUTAzNzk1NDQHSFQgQnVybwICCvMMS0VRMD' \
              'M3OTU1NhlIVCBXb2huemltbWVyIEJhbGtvbnNlaXRlAwIK83lLRVEwMzc5NjY1GkhUIFdvaG56a' \
              'W1tZXIgRmVuc3RlcnNlaXRlAwIK9UBLRVEwMzgwMTIwD0hUIFNjaGxhZnppbW1lcgQB',
          ]
        end
        let(:ret) do
          [
            {
              type: 'M', index: 0, count: 1, unknown: "Vx",
              rooms_count: 1, rooms: [
                { id: '!'.unpack1('C'), name_length: 2, name: 'XY', rf_address: '123'},
              ],
              devices_count: 1, devices: [
                { type: 4, rf_address: 'RFA', serial_number: 'serial_num', name_length: 4, name: 'NAME', room_id: '!'.unpack1('C') },
              ],
            },
            {
              type: 'M', index: 0, count: 1, unknown: "V\x02".b,
              rooms_count: 4, rooms: [
                { id: 1, name_length: 3, name: 'Bad', rf_address: "\x0a\xed\x69".b },
                { id: 2, name_length: 4, name: 'Buro', rf_address: "\x0a\xf3\x00".b },
                { id: 3, name_length: 10, name: 'Wohnzimmer', rf_address: "\x0a\xf3\x0c".b },
                { id: 4, name_length: 12, name: 'Schlafzimmer', rf_address: "\x0a\xf5\x40".b },
              ],
              devices_count: 5, devices: [
                { type: 2, rf_address: "\x0a\xed\x69".b, serial_number: 'KEQ0378040', name_length: 6, name: 'HT Bad', room_id: 1 },
                { type: 2, rf_address: "\x0a\xf3\x00".b, serial_number: 'KEQ0379544', name_length: 7, name: 'HT Buro', room_id: 2 },
                { type: 2, rf_address: "\x0a\xf3\x0c".b, serial_number: 'KEQ0379556', name_length: 25, name: 'HT Wohnzimmer Balkonseite', room_id: 3 },
                { type: 2, rf_address: "\x0a\xf3\x79".b, serial_number: 'KEQ0379665', name_length: 26, name: 'HT Wohnzimmer Fensterseite', room_id: 3 },
                { type: 2, rf_address: "\x0a\xf5\x40".b, serial_number: 'KEQ0380120', name_length: 15, name: 'HT Schlafzimmer', room_id: 4},
              ],
            },
          ]
        end
        it 'returns proper hash' do
          msgs.each_with_index do |m, i|
            expect(recv.recv_msg(m)).to eq(ret[i])
          end
        end
      end
    end

  end
end
