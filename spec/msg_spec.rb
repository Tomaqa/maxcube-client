require 'maxcube/messages/tcp/parser'
require 'maxcube/messages/tcp/serializer'
require_relative 'spec_helper'

include MaxCube

describe 'TCP::Parser' do
  subject(:parser) { Messages::TCP::Parser.new }

  # Proper message examples:
  # A:\r\n
  # H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\n
  # L:Cw/a7QkSGBgoAMwACw/DcwkSGBgoAM8ACw/DgAkSGBgoAM4A\r\n

  describe 'invalid data' do
    context 'empty message' do
      let(:inputs) do
        [
          '',
        ]
      end
      it 'returns empty array' do
        inputs.each do |i|
          expect(parser.parse_tcp_data(i)).to eq([])
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
    #       expect { parser.parse_tcp_data(inp) }.to raise_error TypeError
    #     end
    #   end
    # end

    context 'invalid format' do
      context 'of single message' do
        let(:msgs) do
          [
            '::',
            'HX:',
            'HX:A',
            'HX:A:',
            '1:',
            "A:\x00",
            "A:\r",
            "A:\n",
            "A:\n\r",
          ]
        end
        it 'raises proper exception and #valid_tcp_msg_format and #valid_tcp_msg are falsey' do
          msgs.each do |m|
            expect { parser.parse_tcp_msg(m) }.to raise_error Messages::InvalidMessageFormat
            expect(parser.valid_tcp_msg_format(m)).to be_falsey
            expect(parser.valid_tcp_msg(m)).to be_falsey
          end
        end
        it 'raises proper exception when passed as raw data' do
          msgs.each do |m|
            expect { parser.parse_tcp_data(m) }.to raise_error Messages::InvalidMessageFormat
          end
        end
      end

      context 'of raw data' do
        let(:data) do
          [
            "\r\n",
            "\r\n\r\n",
            'A:\r\n',
            'A:\n',
            'A:\r',
            'A:\r\nA:\r\n',
            "A:\r\nA:\r\naX:\r\n",
            "H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\nA:\r\nA:\r\naX:\r\n",
            "A:\r\nH:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\nA:\r\naX:\r\n",
            "A:\nH:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000\r\nA:\r\naX:\r\n",
          ]
        end
        it 'raises proper exception' do
          data.each do |d|
            expect { parser.parse_tcp_data(d) }.to raise_error Messages::InvalidMessageFormat
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
      it 'raises proper exception and #valid_msg_msg_type and #valid_tcp_msg are falsey' do
        msgs.each do |m|
          expect { parser.parse_tcp_msg(m) }.to raise_error Messages::InvalidMessageType
          expect(parser.valid_msg_msg_type(m)).to be_falsey
          expect(parser.valid_tcp_msg(m)).to be_falsey
        end
      end
    end

    context 'valid message type but parser not implemented (yet)' do
      let(:msgs) do
        [
          'D:ZXhhbXBsZQoAAAAAAAAAAA==',
          'E:encrypted-base64',
          'w:message1,message2,0001',
        ]
      end
      let(:ret) do
        [
          { type: 'D', data: 'ZXhhbXBsZQoAAAAAAAAAAA==' },
          { type: 'E', data: 'encrypted-base64' },
          { type: 'w', data: 'message1,message2,0001'},
        ]
      end
      it 'returns hash with unparsed data' do
        msgs.each_with_index do |m, i|
          expect(parser.parse_tcp_msg(m)).to eq(ret[i])
        end
      end
    end

    context 'invalid message length' do
      let(:msgs) do
        [
          'A',
          ':',
          'A:' + 'x' * Messages::TCP::MSG_MAX_LEN,
        ]
      end
      it 'raises proper exception and #valid_tcp_msg_length and #valid_tcp_msg are falsey' do
        msgs.each do |m|
          expect { parser.parse_tcp_msg(m) }.to raise_error Messages::InvalidMessageLength
          expect(parser.valid_tcp_msg_length(m)).to be_falsey
          expect(parser.valid_tcp_msg(m)).to be_falsey
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
        ary = parser.parse_tcp_data(d)
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
          expect(parser.parse_tcp_msg(m)).to eq({ type: 'A' })
        end
      end
    end

    describe 'C message' do
      context 'invalid message body' do
        let(:msgs) do
          [
            # invalid address
            'C:06c94,' + Base64.strict_encode64("\x12\x06\xc9\x41\x04\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37\x20"),
            'C:06c94x,' + Base64.strict_encode64("\x12\x06\xc9\x41\x04\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37\x20"),
            # insufficient head length
            'C:06c941,' + Base64.strict_encode64("\x11\x06\xc9\x41\x00\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37"),
            'C:06c941,' + Base64.strict_encode64("\x12\x06\xc9\x41\x00\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37"),
            'C:06c941,' + Base64.strict_encode64("\x11\x06\xc9\x41\x01\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37"),
            'C:06c941,' + Base64.strict_encode64("\x12\x06\xc9\x41\x01\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37"),
            'C:06c941,' + Base64.strict_encode64("\x12\x06\xc9\x41\x02\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37"),
            'C:06c941,' + Base64.strict_encode64("\x11\x06\xc9\x41\x04\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37"),
            'C:06c941,' + Base64.strict_encode64("\x12\x06\xc9\x41\x04\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37"),
            # insufficient body length
            'C:06c941,' + Base64.strict_encode64("\x13\x06\xc9\x41\x01\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37\x36"),
            'C:06c941,' + Base64.strict_encode64("\x13\x06\xc9\x41\x02\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37\x36"),
            'C:06c941,' + Base64.strict_encode64("\x13\x06\xc9\x41\x03\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37\x36"),
            # invalid device type
            'C:06c941,' + Base64.strict_encode64("\x12\x06\xc9\x41\x06\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37\x36"),
          ]
        end
        it 'raises proper exception' do
          msgs.each do |m|
            expect{ parser.parse_tcp_msg(m) }.to raise_error Messages::InvalidMessageBody
          end
        end
      end

      context 'valid message body' do
        let(:msgs) do
          [
            # cube data
            'C:03f6c9,7QP2yQATAf9KRVEwNTQzNTQ1AQsABEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAsABEAAAAAAAAAAQQAAAAAAAAAAAAAAAAAAAAAAAAAAAGh0dHA6Ly93d3cubWF4LXBvcnRhbC5lbHYuZGU6ODAvY3ViZQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAENFVAAACgADAAAOEENFU1QAAwACAAAcIA==',
            'C:10b199,7RCxmQATAf9MRVExMTU0NzI3AAsABEAAAAAAAAAAAP///////////////////////////wsABEAAAAAAAAAAQf///////////////////////////2h0dHA6Ly9tYXguZXEtMy5kZTo4MC9jdWJlADAvbG9va3VwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAENFVAAACgADAAAOEENFU1QAAwACAAAcIA==',
            'C:03f25d,' + Base64.strict_encode64("\xed\x03\xf2\x5d\x00\x13\x01\x00\x4a\x45\x51\x30\x35\x34\x34\x39\x32\x33\x00\x0b\x00\x04\x40\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\x0b\x00\x04\x40\x00\x00\x00\x00\x00\x00\x00\x41\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\x68\x74\x74\x70\x3a\x2f\x2f\x6d\x61\x78\x2e\x65\x71\x2d\x33\x2e\x64\x65\x3a\x38\x30\x2f\x63\x75\x62\x65\x00\x30\x2f\x6c\x6f\x6f\x6b\x75\x70\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x43\x45\x54\x00\x00\x0a\x00\x03\x00\x00\x0e\x10\x43\x45\x53\x54\x00\x03\x00\x02\x00\x00\x1c\x20"),
            # radiator thermostat data
            'C:0b04be,0gsEvgIBEP9LRVEwNTcxNjc0LCE9CQcYA1CH/wBETlxmWPxVFEUgRSBFIEUgRSBFIEUgRSBFIEROXGZY/FUURSBFIEUgRSBFIEUgRSBFIEUgRE5cZlj8VRRFIEUgRSBFIEUgRSBFIEUgRSBETlxmWPxVFEUgRSBFIEUgRSBFIEUgRSBFIEROXGZY/FUURSBFIEUgRSBFIEUgRSBFIEUgRE5cZlj8VRRFIEUgRSBFIEUgRSBFIEUgRSBETlxmWPxVFEUgRSBFIEUgRSBFIEUgRSBFIA==',
            'C:08b6d2,0gi20gICEABLRVEwNjM0NjA3LiE9CQcYA1AM/wBETlxmWwhVFEUgRSBFIEUgRSBFIEUgRSBFIEROXGZbCFUURSBFIEUgRSBFIEUgRSBFIEUgRE5cZlsIVRRFIEUgRSBFIEUgRSBFIEUgRSBETlxmWwhVFEUgRSBFIEUgRSBFIEUgRSBFIEROXGZbCFUURSBFIEUgRSBFIEUgRSBFIEUgRE5cZlsIVRRFIEUgRSBFIEUgRSBFIEUgRSBETlxmWwhVFEUgRSBFIEUgRSBFIEUgRSBFIA==',
            'C:122b65,0hIrZQIBEABNRVExNDcyOTk3Oyc9CQcYA5IM/wBESHkPRSBFIEUgRSBFIEUgRSBFIEUgRSBFIERIeQlFIEUgRSBFIEUgRSBFIEUgRSBFIEUgREJ4XkTJeRJFIEUgRSBFIEUgRSBFIEUgRSBEQnheRMl5EkUgRSBFIEUgRSBFIEUgRSBFIERCeF5EyXkSRSBFIEUgRSBFIEUgRSBFIEUgREJ4XkTJeRJFIEUgRSBFIEUgRSBFIEUgRSBEQnheRMl5EkUgRSBFIEUgRSBFIEUgRSBFIA==',
            'C:06c941,' + Base64.strict_encode64("\xd2\x06\xc9\x41\x01\x01\x18\xff\x4b\x45\x51\x30\x33\x35\x32\x32\x37\x36\x24\x20\x3d\x09\x07\x18\x03\xf4\x0c\xff\x00\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x06\x18\xf4"),
            # wall thermostat data
            'C:121707,zhIXBwMBEP9NRVEwODUzNjAzKyE9CURIVQhFIEUgRSBFIEUgRSBFIEUgRSBFIEUgREhVCEUgRSBFIEUgRSBFIEUgRSBFIEUgRSBESFRsRMxVFEUgRSBFIEUgRSBFIEUgRSBFIERIVGxEzFUURSBFIEUgRSBFIEUgRSBFIEUgREhUbETMVRRFIEUgRSBFIEUgRSBFIEUgRSBESFRsRMxVFEUgRSBFIEUgRSBFIEUgRSBFIERIVGxEzFUURSBFIEUgRSBFIEUgRSBFIEUgBxgw',
            'C:0a12bd,' + Base64.strict_encode64("\xce\x0a\x12\xbd\x03\x01\x10\xff\x4b\x45\x51\x30\x37\x30\x34\x37\x35\x32\x24\x20\x3d\x09\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x41\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x45\x20\x06\x18\xf4"),
            # eco button
            'C:01b491,EQG0kQUAEg9KRVEwMzA1MjA1',
          ]
        end
        let(:ret) do
          [
            { type: 'C', length: 237,
              address: '03f6c9', rf_address: 0x03f6c9,
              device_type: :cube,
              firmware_version: '0113',
              test_result: 255,
              serial_number: 'JEQ0543545',
              portal_enabled: true,
              button_up_mode: :auto,
              button_down_mode: :eco,
              portal_url: "http://www.max-portal.elv.de:80/cube\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".b,
            },
            { type: 'C', length: 237,
              address: '10b199', rf_address: 0x10b199,
              device_type: :cube,
              firmware_version: '0113',
              test_result: 255,
              serial_number: 'LEQ1154727',
              portal_enabled: false,
              button_up_mode: :auto,
              button_down_mode: :eco,
              portal_url: "http://max.eq-3.de:80/cube\x000/lookup\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".b,
            },
            { type: 'C', length: 237,
              address: '03f25d', rf_address: 0x03f25d,
              device_type: :cube,
              firmware_version: '0113',
              test_result: 0,
              serial_number: 'JEQ0544923',
              portal_enabled: false,
              button_up_mode: :auto,
              button_down_mode: :eco,
              portal_url: "http://max.eq-3.de:80/cube\x000/lookup\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".b,
            },
            { type: 'C', length: 210,
              address: '0b04be', rf_address: 0x0b04be,
              device_type: :radiator_thermostat_plus,
              room_id: 1, _firmware_version: 16,
              test_result: 255,
              serial_number: 'KEQ0571674',
              comfort_temperature: 22.0,
              eco_temperature: 16.5,
              max_setpoint_temperature: 30.5,
              min_setpoint_temperature: 4.5,
              temperature_offset: 0.0,
              window_open_temperature: 12.0,
              window_open_duration: 15,
              boost_duration: 10,
              valve_opening: 80,
              decalcification_day: 'Wednesday',
              decalcification_hour: 7,
              max_valve_setting: 100.0,
              valve_offset: 0.0,
            },
            { type: 'C', length: 210,
              address: '08b6d2', rf_address: 0x08b6d2,
              device_type: :radiator_thermostat_plus,
              room_id: 2, _firmware_version: 16,
              test_result: 0,
              serial_number: 'KEQ0634607',
              comfort_temperature: 23.0,
              eco_temperature: 16.5,
              max_setpoint_temperature: 30.5,
              min_setpoint_temperature: 4.5,
              temperature_offset: 0.0,
              window_open_temperature: 12.0,
              window_open_duration: 15,
              boost_duration: 10,
              valve_opening: 80,
              decalcification_day: 'Saturday',
              decalcification_hour: 12,
              max_valve_setting: 100.0,
              valve_offset: 0.0,
            },
            { type: 'C', length: 210,
              address: '122b65', rf_address: 0x122b65,
              device_type: :radiator_thermostat_plus,
              room_id: 1, _firmware_version: 16,
              test_result: 0,
              serial_number: 'MEQ1472997',
              comfort_temperature: 29.5,
              eco_temperature: 19.5,
              max_setpoint_temperature: 30.5,
              min_setpoint_temperature: 4.5,
              temperature_offset: 0.0,
              window_open_temperature: 12.0,
              window_open_duration: 15,
              boost_duration: 20,
              valve_opening: 90,
              decalcification_day: 'Saturday',
              decalcification_hour: 12,
              max_valve_setting: 100.0,
              valve_offset: 0.0,
            },
            { type: 'C', length: 210,
              address: '06c941', rf_address: 0x06c941,
              device_type: :radiator_thermostat,
              room_id: 1, _firmware_version: 24,
              test_result: 255,
              serial_number: 'KEQ0352276',
              comfort_temperature: 18.0,
              eco_temperature: 16.0,
              max_setpoint_temperature: 30.5,
              min_setpoint_temperature: 4.5,
              temperature_offset: 0.0,
              window_open_temperature: 12.0,
              window_open_duration: 15,
              boost_duration: 60,
              valve_opening: 100,
              decalcification_day: 'Saturday',
              decalcification_hour: 12,
              max_valve_setting: 100.0,
              valve_offset: 0.0,
            },
            { type: 'C', length: 206,
              address: '121707', rf_address: 0x121707,
              device_type: :wall_thermostat,
              room_id: 1, _firmware_version: 16,
              test_result: 255,
              serial_number: 'MEQ0853603',
              comfort_temperature: 21.5,
              eco_temperature: 16.5,
              max_setpoint_temperature: 30.5,
              min_setpoint_temperature: 4.5,
              unknown: "\x07\x18\x30".b,
            },
            { type: 'C', length: 206,
              address: '0a12bd', rf_address: 0x0a12bd,
              device_type: :wall_thermostat,
              room_id: 1, _firmware_version: 16,
              test_result: 255,
              serial_number: 'KEQ0704752',
              comfort_temperature: 18.0,
              eco_temperature: 16.0,
              max_setpoint_temperature: 30.5,
              min_setpoint_temperature: 4.5,
              unknown: "\x06\x18\xf4".b,
            },
            { type: 'C', length: 17,
              address: '01b491', rf_address: 0x01b491,
              device_type: :eco_switch,
              room_id: 0, _firmware_version: 18,
              test_result: 15,
              serial_number: 'JEQ0305205',
            },
          ]
        end
        it 'returns proper hash' do
          msgs.each_with_index do |m, i|
            expect(parser.parse_tcp_msg(m)
              .delete_if do |k, _|
                [
                  :unknown1, :unknown2, :unknown3, :unknown4,
                  # :_timezone_winter, :_timezone_winter_offset,
                  # :timezone_winter_day, :timezone_winter_month,
                  # :_timezone_daylight, :_timezone_daylight_offset,
                  # :timezone_daylight_day, :timezone_daylight_month,
                  :weekly_program
                ].include?(k)
              end).to eq(ret[i])
          end
        end
      end
    end

    # F:ntp.homematic.com,ntp.homematic.com
    describe 'F message' do
      let(:msgs) do
        [
          'F:',
          'F:ntp.homematic.com',
          'F:ntp.homematic.com,',
          'F:ntp.homematic.com,ntp.homematic.com',
        ]
      end
      let(:ret) do
        [
          { type: 'F', ntp_servers: [] },
          { type: 'F', ntp_servers: ['ntp.homematic.com'] },
          { type: 'F', ntp_servers: ['ntp.homematic.com'] },
          { type: 'F', ntp_servers: ['ntp.homematic.com', 'ntp.homematic.com'] },
        ]
      end
      it 'returns proper hash' do
        msgs.each_with_index do |m, i|
          expect(parser.parse_tcp_msg(m)).to eq(ret[i])
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
            'H:IKEQ0523864,197f2c,0113,0000000,477719c0,00,32,0d0c09,1404,03,0000',
            'H:IKEQ0523864,197f2c,0113,00000000,77719c0,00,32,0d0c09,1404,03,0000',
            'H:IKEQ0523864,197f2c,0113,00000000,477719c0,0,32,0d0c09,1404,03,0000',
            'H:IKEQ0523864,197f2c,0113,00000000,477719c0,00,2,0d0c09,1404,03,0000',
            'H:IKEQ0523864,197f2c,0113,00000000,477719c0,00,32,d0c09,1404,03,0000',
            'H:IKEQ0523864,197f2c,0113,00000000,477719c0,00,32,0d0c09,404,03,0000',
            'H:IKEQ0523864,197f2c,0113,00000000,477719c0,00,32,0d0c09,1404,3,0000',
            'H:IKEQ0523864,197f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,000',
            # invalid hex format
            'H:KEQ0523864,x97f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000',
            'H:KEQ0523864,097f2c,x113,00000000,477719c0,00,32,0d0c09,1404,03,0000',
            'H:KEQ0523864,097f2c,0113,00000000,477719cx,00,32,0d0c09,1404,03,0000',
            'H:KEQ0523864,097f2c,0113,00000000,477719c0,x0,32,0d0c09,1404,03,0000',
            'H:KEQ0523864,097f2c,0113,00000000,477719c0,00,3g,0d0c09,1404,03,0000',
          ]
        end
        it 'raises proper exception' do
          msgs.each do |m|
            expect{ parser.parse_tcp_msg(m) }.to raise_error Messages::InvalidMessageBody
          end
        end
      end

      context 'valid message body' do
        let(:msgs) do
          [
            'H:KEQ0523864,097f2c,0113,00000000,477719c0,00,32,0d0c09,1404,03,0000',
            'H:4KFK49VMD6,c233fe,211f,00000000,478819c0,16,3c,000a03,1024,03,00fd',
            'H:JEQ0544923,03f25d,0113,00000000,299ca43f,00,32,0d0c1d,1013,03,0000',
            'H:JEQ0543545,03f6c9,0113,00000000,2663651e,00,32,0d0c0f,000c,03,0000',
        
          ]
        end
        let(:ret) do
          [
            { type: 'H', serial_number: 'KEQ0523864', rf_address: 0x097f2c,
              firmware_version: '0113', unknown: '00000000',
              http_id: 0x477719c0, duty_cycle: 0, free_memory_slots: 50,
              cube_datetime: Time.new(2013, 12, 9, 20, 4),
              state_cube_time: 3, ntp_counter: 0 },
            { type: 'H', serial_number: '4KFK49VMD6', rf_address: 0xc233fe,
              firmware_version: '211f', unknown: '00000000',
              http_id: 0x478819c0, duty_cycle: 22, free_memory_slots: 60,
              cube_datetime: Time.new(2000, 10, 3, 16, 36),
              state_cube_time: 3, ntp_counter: 253 },
            { type: 'H', serial_number: 'JEQ0544923', rf_address: 0x03f25d,
              firmware_version: '0113', unknown: '00000000',
              http_id: 0x299ca43f, duty_cycle: 0, free_memory_slots: 50,
              cube_datetime: Time.new(2013, 12, 29, 16, 19),
              state_cube_time: 3, ntp_counter: 0 },
            { type: 'H', serial_number: 'JEQ0543545', rf_address: 0x03f6c9,
              firmware_version: '0113', unknown: '00000000',
              http_id: 0x2663651e, duty_cycle: 0, free_memory_slots: 50,
              cube_datetime: Time.new(2013, 12, 15, 0, 12),
              state_cube_time: 3, ntp_counter: 0 },
          ]
        end
        it 'returns proper hash' do
          msgs.each_with_index do |m, i|
            expect(parser.parse_tcp_msg(m)).to eq(ret[i])
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
            expect{ parser.parse_tcp_msg(m) }.to raise_error Messages::InvalidMessageBody
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
            'L:' + Base64.strict_encode64("\x0b\x0f\xda\xed\x09\x12\x18\x18\xa8\xbd\xef\x04"),
            'L:' + Base64.strict_encode64("\x0b\x0f\xda\xed\x09\x12\x18\x18\xa8\xbd\xf0\x05"),
            'L:Cw/a7QkSGBgoAMwACw/DcwkSGBgoAM8ACw/DgAkSGBgoAM4A',
            'L:CwsEvvYSGAAiANsACwi20lwSGAAiAOEABgG0kVwSEF==',
        
          ]
        end
        let(:ret) do
          [
            { type: 'L', devices: [] },
            { type: 'L', devices: [
                { length: 6, rf_address: 0x0fdaed, unknown: "\x09".b,
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
                { length: 11, rf_address: 0x0fdaed, unknown: "\x09".b,
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
                  valve_opening: 24, temperature: 12.0,
                  actual_temperature: 25.6,
                },
              ],
            },
            { type: 'L', devices: [
                { length: 12, rf_address: 0x0fdaed, unknown: "\x09".b,
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
                  valve_opening: 24, temperature: 20.0,
                  datetime_until: Time.new(2011, 8, 29, 2, 0),
                  actual_temperature: 29.2,
                },
              ],
            },
            { type: 'L', devices: [
                { length: 11, rf_address: 0x0fdaed, unknown: "\x09".b,
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
                  valve_opening: 24, temperature: 20.0,
                  datetime_until: Time.new(2015, 11, 29, 2, 0),
                },
              ],
            },
            { type: 'L', devices: [
                { length: 11, rf_address: 0x0fdaed, unknown: "\x09".b,
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
                  valve_opening: 24, temperature: 20.0,
                  datetime_until: Time.new(2016, 11, 29, 2, 30),
                },
              ],
            },
            { type: 'L', devices: [
                {
                  length: 11, rf_address: 0x0fdaed, unknown: "\x09".b,
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
                  valve_opening: 24, temperature: 20.0,
                  actual_temperature: 20.4,
                },
                {
                  length: 11, rf_address: 0x0fc373, unknown: "\x09".b,
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
                  valve_opening: 24, temperature: 20.0,
                  actual_temperature: 20.7,
                },
                {
                  length: 11, rf_address: 0x0fc380, unknown: "\x09".b,
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
                  valve_opening: 24, temperature: 20.0,
                  actual_temperature: 20.6,
                },
              ],
            },
            { type: 'L', devices: [
                {
                  length: 11, rf_address: 0x0b04be, unknown: "\xf6".b,
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
                  valve_opening: 0, temperature: 17.0,
                  actual_temperature: 21.9,
                },
                {
                  length: 11, rf_address: 0x08b6d2, unknown: "\x5c".b,
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
                  valve_opening: 0, temperature: 17.0,
                  actual_temperature: 22.5,
                },
                {
                  length: 6, rf_address: 0x01b491, unknown: "\x5c".b,
                  flags: {
                    value: 0x1210,
                    mode: :auto,
                    dst_setting_active: false,
                    gateway_known: true,
                    panel_locked: false,
                    link_error: false,
                    low_battery: false,
                    status_initialized: true,
                    is_answer: false,
                    error: false,
                    valid_info: true,
                  },
                },
              ],
            },
          ]
        end
        it 'returns proper hash' do
          msgs.each_with_index do |m, i|
            expect(parser.parse_tcp_msg(m)).to eq(ret[i])
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
            # invalid device type
            'M:00,01,' + Base64.strict_encode64("Vx\x01!\x02XY123\x01\x07RFAserial_num\x04NAME!"),
          ]
        end
        it 'raises proper exception' do
          msgs.each do |m|
            expect{ parser.parse_tcp_msg(m) }.to raise_error Messages::InvalidMessageBody
          end
        end
      end

      context 'valid message body' do
        let(:msgs) do
          [
            'M:00,01,' + Base64.strict_encode64("Vx\x01!\x02XY123\x01\x04RFAserial_num\x04NAME!\x01"),
            'M:00,01,VgIEAQNCYWQK7WkCBEJ1cm8K8wADCldvaG56aW1tZXIK8wwEDFNjaGxhZnppbW1lcgr' \
              '1QAUCCu1pS0VRMDM3ODA0MAZIVCBCYWQBAgrzAEtFUTAzNzk1NDQHSFQgQnVybwICCvMMS0VRMD' \
              'M3OTU1NhlIVCBXb2huemltbWVyIEJhbGtvbnNlaXRlAwIK83lLRVEwMzc5NjY1GkhUIFdvaG56a' \
              'W1tZXIgRmVuc3RlcnNlaXRlAwIK9UBLRVEwMzgwMTIwD0hUIFNjaGxhZnppbW1lcgQB',
            'M:00,01,VgICAg1PYnl2YWNpIHBva29qCLbSAQdQcmVkc2luCwS+AwILBL5LRVEwNTcxNjc0C3RvcGVuaSB1IHdjAQIIttJLRVEwNjM0NjA3CVBvZCBva25lbQIFAbSRSkVRMDMwNTIwNQpFY28gU3dpdGNoAAE=',
          ]
        end
        let(:ret) do
          [
            {
              type: 'M', index: 0, count: 1, unknown1: 'Vx', unknown2: "\x01".b,
              rooms_count: 1, rooms: [
                { id: '!'.unpack1('C'), name_length: 2, name: 'XY', rf_address: 0x313233, },
              ],
              devices_count: 1, devices: [
                { type: :shutter_contact, rf_address: 0x524641, serial_number: 'serial_num', name_length: 4, name: 'NAME', room_id: '!'.unpack1('C') },
              ],
            },
            {
              type: 'M', index: 0, count: 1, unknown1: "V\x02".b, unknown2: "\x01".b,
              rooms_count: 4, rooms: [
                { id: 1, name_length: 3, name: 'Bad', rf_address: 0x0aed69, },
                { id: 2, name_length: 4, name: 'Buro', rf_address: 0x0af300, },
                { id: 3, name_length: 10, name: 'Wohnzimmer', rf_address: 0x0af30c, },
                { id: 4, name_length: 12, name: 'Schlafzimmer', rf_address: 0x0af540, },
              ],
              devices_count: 5, devices: [
                { type: :radiator_thermostat_plus, rf_address: 0x0aed69, serial_number: 'KEQ0378040', name_length: 6, name: 'HT Bad', room_id: 1, },
                { type: :radiator_thermostat_plus, rf_address: 0x0af300, serial_number: 'KEQ0379544', name_length: 7, name: 'HT Buro', room_id: 2, },
                { type: :radiator_thermostat_plus, rf_address: 0x0af30c, serial_number: 'KEQ0379556', name_length: 25, name: 'HT Wohnzimmer Balkonseite', room_id: 3, },
                { type: :radiator_thermostat_plus, rf_address: 0x0af379, serial_number: 'KEQ0379665', name_length: 26, name: 'HT Wohnzimmer Fensterseite', room_id: 3, },
                { type: :radiator_thermostat_plus, rf_address: 0x0af540, serial_number: 'KEQ0380120', name_length: 15, name: 'HT Schlafzimmer', room_id: 4, },
              ],
            },
            {
              type: 'M', index: 0, count: 1, unknown1: "V\x02".b, unknown2: "\x01".b,
              rooms_count: 2, rooms: [
                { id: 2, name_length: 13, name: 'Obyvaci pokoj', rf_address: 0x08b6d2, },
                { id: 1, name_length: 7, name: 'Predsin', rf_address: 0x0b04be, },
              ],
              devices_count: 3, devices: [
                { type: :radiator_thermostat_plus, rf_address: 0x0b04be, serial_number: 'KEQ0571674', name_length: 11, name: 'topeni u wc', room_id: 1, },
                { type: :radiator_thermostat_plus, rf_address: 0x08b6d2, serial_number: 'KEQ0634607', name_length: 9, name: 'Pod oknem', room_id: 2, },
                { type: :eco_switch, rf_address: 0x01b491, serial_number: 'JEQ0305205', name_length: 10, name: 'Eco Switch', room_id: 0, },
              ],
            },
          ]
        end
        it 'returns proper hash' do
          msgs.each_with_index do |m, i|
            expect(parser.parse_tcp_msg(m)).to eq(ret[i])
          end
        end
      end
    end

    # N:Aw4VzExFUTAwMTUzNDD/
    describe 'N message' do
      context 'invalid message body' do
        let(:msgs) do
          [
            # invalid device type
            'N:' + Base64.strict_encode64("\x06\x0e\x15\xccLEQ0015340\xff"),
            # invalid length
            'N:' + Base64.strict_encode64("\x00\x0e\x15\xccLEQ0015340"),
          ]
        end
        it 'raises proper exception' do
          msgs.each do |m|
            expect{ parser.parse_tcp_msg(m) }.to raise_error Messages::InvalidMessageBody
          end
        end
      end

      context 'valid message body' do
        let(:msgs) do
          [
            'N:Aw4VzExFUTAwMTUzNDD/',
          ]
        end
        let(:ret) do
          [
            { type: 'N', device_type: :wall_thermostat,
              rf_address: 0x0e15cc,
              serial_number: 'LEQ0015340',
              unknown: "\xff".b,
            },
          ]
        end
        it 'returns proper hash' do
          msgs.each_with_index do |m, i|
            expect(parser.parse_tcp_msg(m)).to eq(ret[i])
          end
        end
      end
    end

    # S:00,0,31
    describe 'S message' do
      context 'invalid message body' do
        let(:msgs) do
          [
            # invalid lengths of message parts
            'S:',
            'S:0,0,1',
            'S:00,0',
            'S:0,0,31',
            'S:00,,31',
            # invalid hex format
            'S:0x,0,31',
            'S:00,s,31',
            'S:00,0,3g',
          ]
        end
        it 'raises proper exception' do
          msgs.each do |m|
            expect{ parser.parse_tcp_msg(m) }.to raise_error Messages::InvalidMessageBody
          end
        end
      end

      context 'valid message body' do
        let(:msgs) do
          [
            'S:00,0,31',
            'S:00,1,31',
            'S:63,2,fd',
          ]
        end
        let(:ret) do
          [
            { type: 'S',
              duty_cycle: 0, command_processed: true,
              free_memory_slots: 49 },
            { type: 'S',
              duty_cycle: 0, command_processed: false,
              free_memory_slots: 49 },
            { type: 'S',
              duty_cycle: 99, command_processed: false,
              free_memory_slots: 253 },
          ]
        end
        it 'returns proper hash' do
          msgs.each_with_index do |m, i|
            expect(parser.parse_tcp_msg(m)).to eq(ret[i])
          end
        end
      end
    end

  end
end

describe 'TCP::Serializer' do
  subject(:serializer) { Messages::TCP::Serializer.new }

  # Proper message examples:
  # a:\r\n
  # n:003c\r\n
  # q:\r\n
  # t:01,1,Dx1U\r\n

  describe 'invalid data' do
    context 'empty data' do
      let(:inputs) do
        [
          [],
        ]
      end
      it 'returns empty data' do
        inputs.each do |i|
          expect(serializer.serialize_tcp_hashes(i)).to eq('')
        end
      end
    end

    context 'invalid message type' do
      let(:hashes) do
        [
          {},
          { type_: 'a', },
          { _type: 'a', },
          { type: 'aa' },
          { type: 'X' },
          { type: 'A' },
        ]
      end
      it 'raises proper exception and #valid_hash_msg_type and #valid_tcp_hash are falsey' do
        hashes.each do |h|
          expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageType
          expect(serializer.valid_hash_msg_type(h)).to be_falsey
          expect(serializer.valid_tcp_hash(h)).to be_falsey
        end
      end
      it 'raises proper exception when passed as array of hashes' do
        hashes.each do |h|
          expect{ serializer.serialize_tcp_hashes([h]) }.to raise_error Messages::InvalidMessageType
        end
      end
    end

    context 'invalid hash keys' do
      let(:hashes) do
        [
          { type: 'm' },
          { type: 'm', data: 'data' },
          { type: 'm', data: 'data', rooms_count: 1, rooms: [],
            devices_count: 1, devices: [], },
          { type: 'a', data: 'data' },
          { type: 'a', data: nil },
        ]
      end
      it 'raises proper exception and #valid_hash_keys and #valid_tcp_hash are falsey' do
        hashes.each do |h|
          expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
          expect(serializer.valid_hash_keys(h)).to be_falsey
          expect(serializer.valid_tcp_hash(h)).to be_falsey
        end
      end
      it 'raises proper exception when passed as array of hashes' do
        hashes.each do |h|
          expect{ serializer.serialize_tcp_hashes([h]) }.to raise_error Messages::InvalidMessageBody
        end
      end
    end

    context 'invalid hash values' do
      let(:hashes) do
        [
          { type: 'u', url: 'URL', port: nil },
          { type: 'u', url: nil, port: 80 },
        ]
      end
      it 'raises proper exception and #valid_hash_values and #valid_tcp_hash are falsey' do
        hashes.each do |h|
          expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
          expect(serializer.valid_hash_values(h)).to be_falsey
          expect(serializer.valid_tcp_hash(h)).to be_falsey
        end
      end
      it 'raises proper exception when passed as array of hashes' do
        hashes.each do |h|
          expect{ serializer.serialize_tcp_hashes([h]) }.to raise_error Messages::InvalidMessageBody
        end
      end
    end

    context 'valid message type but serializer not implemented yet' do
      let(:hashes) do
        [
          { type: 'g' },
          { type: 'W' },
          { type: 'r' },
        ]
      end
      it 'raises proper exception' do
        hashes.each do |h|
          expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageType
        end
      end
    end

  # ! Check whether output data is valid: length is not too long, format is OK, ..

  end

  describe 'valid data' do
    let(:data) do
      [
        [{ type: 'a'}, ],
        [{ type: 'a'}, { type: 'a'}, ],
        [{ type: 'a'}, { type: 'l'}, { type: 'a'}, ],
        [{ type: 'l'}, { type: 'l'}, { type: 'a'}, ],
        [{ type: 'q'}, { type: 'l'}, { type: 'a'}, ],
      ]
    end
    let(:res) do
      [
        %w[a],
        %w[a a],
        %w[a l a],
        %w[l l a],
        %w[q l a],
      ]
    end
    it 'returns string with valid format and proper message types' do
      data.each_with_index do |d, i|
        data = serializer.serialize_tcp_hashes(d)
        expect(data).to be_a(String)
        expect(serializer.valid_tcp_data(data)).to be_truthy
        expect(data[0]).to eq(res[i][0])
        data.split("\r\n").each_with_index do |m, j|
          expect(serializer.valid_tcp_msg(m)).to be_truthy
          expect(m[0]).to eq(res[i][j])
        end
      end
    end
  end

  describe 'concrete message types' do

    describe 'a, c, l, q messages' do
      let(:types) { %w[a c l q] }
      context 'invalid hash' do
        let(:hashes) do
          [
            { unknown: 'something' },
            { data: 'super interesting' },
          ]
        end
        it 'raises proper exception' do
          types.each do |t|
            hashes.each do |h|
              h[:type] = t
              expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
            end
          end
        end
      end
      context 'valid hash' do
        let(:hashes) do
          [
            {},
          ]
        end
        it 'returns proper string (without any additional content)' do
          types.each do |t|
            hashes.each do |h|
              h[:type] = t
              expect(serializer.serialize_tcp_hash(h)).to eq("#{t}:\r\n")
            end
          end
        end
      end
    end

    # f:
    # f:nl.pool.ntp.org,ntp.homematic.com
    describe 'f message' do
      context 'valid hash' do
        let(:hashes) do
          [
            { type: 'f', },
            { type: 'f', ntp_servers: [], },
            { type: 'f', ntp_servers: ['nl.pool.ntp.org'], },
            { type: 'f', ntp_servers: ['nl.pool.ntp.org', 'ntp.homematic.com'], },
          ]
        end
        let(:ret) do
          [
            'f:',
            'f:',
            'f:nl.pool.ntp.org',
            'f:nl.pool.ntp.org,ntp.homematic.com',
          ].map { |s| s << "\r\n" }
        end
        it 'returns proper string' do
          hashes.each_with_index do |h, i|
            expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
          end
        end
      end
    end

    # m:00,VgIEAQNCYWQK7WkCBEJ1cm8K8wADCldvaG56aW1tZXIK8wwEDFNjaGxhZnppbW1lcgr
    #   1QAUCCu1pS0VRMDM3ODA0MAZIVCBCYWQBAgrzAEtFUTAzNzk1NDQHSFQgQnVybwICCvMMS0VRMD
    #   M3OTU1NhlIVCBXb2huemltbWVyIEJhbGtvbnNlaXRlAwIK83lLRVEwMzc5NjY1GkhUIFdvaG56a
    #   W1tZXIgRmVuc3RlcnNlaXRlAwIK9UBLRVEwMzgwMTIwD0hUIFNjaGxhZnppbW1lcgQB
    describe 'm message' do
      context 'invalid hash' do
        let(:hashes) do
          [
            # invalid values
            {
              type: 'm', index: 'x', rooms_count: 1, devices_count: 1,
              rooms: [{ id: '!'.unpack1('C'), name_length: 2, name: 'XY', rf_address: 0x313233}],
              devices: [{ type: :shutter_contact, rf_address: 0x524641, serial_number: 'serial_num', name_length: 4, name: 'NAME', room_id: '!'.unpack1('C') }],
            },
            {
              type: 'm', rooms_count: 'x', devices_count: 1,
              rooms: [{ id: '!'.unpack1('C'), name_length: 2, name: 'XY', rf_address: 0x313233}],
              devices: [{ type: :shutter_contact, rf_address: 0x524641, serial_number: 'serial_num', name_length: 4, name: 'NAME', room_id: '!'.unpack1('C') }],
            },
            {
              type: 'm', rooms_count: '1', devices_count: 'x',
              rooms: [{ id: '!'.unpack1('C'), name_length: 2, name: 'XY', rf_address: 0x313233}],
              devices: [{ type: :shutter_contact, rf_address: 0x524641, serial_number: 'serial_num', name_length: 4, name: 'NAME', room_id: '!'.unpack1('C') }],
            },
            {
              type: 'm', rooms_count: '1', devices_count: '1',
              rooms: [{ id: '!', name_length: '2', name: 'XY', rf_address: 0x313233}],
              devices: [{ type: :shutter_contact, rf_address: 0x524641, serial_number: 'serial_num', name_length: 4, name: 'NAME', room_id: '!'.unpack1('C') }],
            },
            {
              type: 'm', rooms_count: '1', devices_count: '1',
              rooms: [{ id: '!'.unpack1('C'), name_length: 'x', name: 'XY', rf_address: 0x313233}],
              devices: [{ type: :shutter_contact, rf_address: 0x524641, serial_number: 'serial_num', name_length: 4, name: 'NAME', room_id: '!'.unpack1('C') }],
            },
            {
              type: 'm', rooms_count: '1', devices_count: '1',
              rooms: [{ id: '!'.unpack1('C'), name_length: '2', name: 'XY', rf_address: 'x313233'}],
              devices: [{ type: :shutter_contact, rf_address: 0x524641, serial_number: 'serial_num', name_length: 4, name: 'NAME', room_id: '!'.unpack1('C') }],
            },
            {
              type: 'm', rooms_count: '1', devices_count: '1',
              rooms: [{ id: '!'.unpack1('C'), name_length: '2', name: 'XY', rf_address: '0x313233'}],
              devices: [{ type: 'shutter_contact', rf_address: 'x524641', serial_number: 'serial_num', name_length: 4, name: 'NAME', room_id: '!'.unpack1('C') }],
            },
            {
              type: 'm', rooms_count: '1', devices_count: '1',
              rooms: [{ id: '!'.unpack1('C'), name_length: '2', name: 'XY', rf_address: '0x313233'}],
              devices: [{ type: 'shutter_contact', rf_address: '0x524641', serial_number: 'serial_num', name_length: 'x', name: 'NAME', room_id: '!'.unpack1('C') }],
            },
            {
              type: 'm', rooms_count: '1', devices_count: '1',
              rooms: [{ id: '!'.unpack1('C'), name_length: '2', name: 'XY', rf_address: '0x313233'}],
              devices: [{ type: 'shutter_contact', rf_address: '0x524641', serial_number: 'serial_num', name_length: 4, name: 'NAME', room_id: '!' }],
            },

            # name length mismatch
            {
              type: 'm', rooms_count: '1', devices_count: '1',
              rooms: [{ id: '!'.unpack1('C'), name_length: '3', name: 'XY', rf_address: '0x313233'}],
              devices: [{ type: :shutter_contact, rf_address: 0x524641, serial_number: 'serial_num', name_length: 4, name: 'NAME', room_id: '!'.unpack1('C') }],
            },
            {
              type: 'm', rooms_count: '1', devices_count: '1',
              rooms: [{ id: '!'.unpack1('C'), name_length: 2, name: 'XY', rf_address: '0x313233'}],
              devices: [{ type: :shutter_contact, rf_address: 0x524641, serial_number: 'serial_num', name_length: 3, name: 'NAME', room_id: '!'.unpack1('C') }],
            },
          ]
        end
        it 'raises proper exception' do
          hashes.each do |h|
            expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
          end
        end
      end
      context 'valid hash' do
        let(:hashes) do
          [
            {
              type: 'm', index: 0, unknown1: 'Vx', unknown2: "\x01".b,
              rooms_count: 1, rooms: [
                { id: '!'.unpack1('C'), name_length: 2, name: 'XY', rf_address: 0x313233},
              ],
              devices_count: 1, devices: [
                { type: 'shutter_contact', rf_address: 0x524641, serial_number: 'serial_num', name_length: 4, name: 'NAME', room_id: '!'.unpack1('C') },
              ],
            },
            {
              type: 'm',
              rooms_count: 1, rooms: [
                { id: '!'.unpack1('C'), name: 'XY', rf_address: 0x313233},
              ],
              devices_count: 1, devices: [
                { type: :shutter_contact, rf_address: 0x524641, serial_number: 'serial_num', name: 'NAME', room_id: '!'.unpack1('C') },
              ],
            },
            {
              type: 'm', index: 0, unknown1: "V\x02".b, unknown2: "\x01".b,
              rooms_count: 4, rooms: [
                { id: 1, name_length: 3, name: 'Bad', rf_address: 0x0aed69 },
                { id: 2, name_length: 4, name: 'Buro', rf_address: 0x0af300 },
                { id: 3, name_length: 10, name: 'Wohnzimmer', rf_address: 0x0af30c },
                { id: 4, name_length: 12, name: 'Schlafzimmer', rf_address: 0x0af540 },
              ],
              devices_count: 5, devices: [
                { type: :radiator_thermostat_plus, rf_address: 0x0aed69, serial_number: 'KEQ0378040', name_length: 6, name: 'HT Bad', room_id: 1 },
                { type: :radiator_thermostat_plus, rf_address: 0x0af300, serial_number: 'KEQ0379544', name_length: 7, name: 'HT Buro', room_id: 2 },
                { type: :radiator_thermostat_plus, rf_address: 0x0af30c, serial_number: 'KEQ0379556', name_length: 25, name: 'HT Wohnzimmer Balkonseite', room_id: 3 },
                { type: :radiator_thermostat_plus, rf_address: 0x0af379, serial_number: 'KEQ0379665', name_length: 26, name: 'HT Wohnzimmer Fensterseite', room_id: 3 },
                { type: :radiator_thermostat_plus, rf_address: 0x0af540, serial_number: 'KEQ0380120', name_length: 15, name: 'HT Schlafzimmer', room_id: 4},
              ],
            },
          ]
        end
        let(:ret) do
          [
            'm:00,' + Base64.strict_encode64("Vx\x01!\x02XY123\x01\x04RFAserial_num\x04NAME!\x01"),
            # 'm:00,' + Base64.strict_encode64("Vx\x01!\x02XY123\x01\x04RFAserial_num\x04NAME!\x01"),
            'm:00,' + Base64.strict_encode64("\x00\x00\x01!\x02XY123\x01\x04RFAserial_num\x04NAME!\x00"),
            'm:00,VgIEAQNCYWQK7WkCBEJ1cm8K8wADCldvaG56aW1tZXIK8wwEDFNjaGxhZnppbW1lcgr' \
              '1QAUCCu1pS0VRMDM3ODA0MAZIVCBCYWQBAgrzAEtFUTAzNzk1NDQHSFQgQnVybwICCvMMS0VRMD' \
              'M3OTU1NhlIVCBXb2huemltbWVyIEJhbGtvbnNlaXRlAwIK83lLRVEwMzc5NjY1GkhUIFdvaG56a' \
              'W1tZXIgRmVuc3RlcnNlaXRlAwIK9UBLRVEwMzgwMTIwD0hUIFNjaGxhZnppbW1lcgQB',
          ].map { |s| s << "\r\n" }
        end
        it 'returns proper string' do
          hashes.each_with_index do |h, i|
            expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
          end
        end
      end
    end

    # n:
    # n:003c
    describe 'n message' do
      context 'invalid hash' do
        let(:hashes) do
          [
            # invalid values
            { type: 'n', timeout: 'x' },
          ]
        end
        it 'raises proper exception' do
          hashes.each do |h|
            expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
          end
        end
      end
      context 'valid hash' do
        let(:hashes) do
          [
            { type: 'n', },
            { type: 'n', timeout: 60 },
          ]
        end
        let(:ret) do
          [
            'n:',
            'n:003c',
          ].map { |s| s << "\r\n" }
        end
        it 'returns proper string' do
          hashes.each_with_index do |h, i|
            expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
          end
        end
      end
    end

    # s:AARAAAAAB5EAAWY=
    describe 's message' do
      context 'invalid hash head' do
        let(:hashes) do
          [
            # invalid values
            { type: 's', unknown: "\x00".b,
              command: :set_temperature_mode,
              rf_address_from: 'x', rf_address: '1', room_id: 1,
              temperature: 19.0, mode: :manual, },
            { type: 's', unknown: "\x00".b,
              command: :set_temperature_mode,
              rf_address_from: '0', rf_address: 'x', room_id: 1,
              temperature: 19.0, mode: :manual, },
            { type: 's', unknown: "\x00".b,
              command: :set_temperature_modex,
              rf_address_from: '0', rf_address: '1', room_id: 1,
              temperature: 19.0, mode: :manual, },
            { type: 's', rf_flags: 'x1',
              command: :set_temperature_mode,
              rf_address_to: 0x179101, room_id: 3,
              temperature: 24.0, mode: :vacation, },
          ]
        end
        it 'raises proper exception' do
          hashes.each do |h|
            expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
          end
        end
      end
      context 'set temperature and mode' do
        context 'invalid hash body' do
          let(:hashes) do
            [
              # invalid values
              { type: 's', unknown: "\x00".b,
                command: 'set_temperature_mode',
                rf_address_range: 0..0x079100, room_id: 'x',
                temperature: 19.0, mode: 'manual', },
              { type: 's', unknown: "\x00".b,
                command: 'set_temperature_mode',
                rf_address_range: 0..0x079100, room_id: '1',
                temperature: 'x', mode: 'manual', },
              { type: 's', unknown: "\x00".b,
                command: :set_temperature_mode,
                rf_address_range: 4..0x079100, room_id: 1,
                temperature: 19.0, mode: :vacation,
                datetime_until: 'x' },
            ]
          end
          it 'raises proper exception' do
            hashes.each do |h|
              expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
            end
          end
        end
        context 'valid hash' do
          let(:hashes) do
            [
              { type: 's', unknown: "\x00".b,
                command: 'set_temperature_mode',
                rf_address_range: 0..0x079100, room_id: 1,
                temperature: 19.0, mode: 'manual', },
              { type: 's', unknown: "\x00".b,
                command: :set_temperature_mode,
                rf_address_range: 4..0x079100, room_id: 1,
                temperature: 19.0, mode: :vacation,
                datetime_until: Time.new(2011, 8, 29, 2, 0) },
              { type: 's', unknown: "\x00".b,
                command: :set_temperature_mode,
                rf_address_range: 4..0x079100, room_id: 1,
                temperature: 19.0, mode: :vacation,
                datetime_until: '2011-08-29 02:00' },
              { type: 's', unknown: "\x00".b,
                command: :set_temperature_mode,
                rf_address: 0x179101, room_id: 3,
                temperature: 19.0, mode: :vacation,
                datetime_until: Time.new(2015, 11, 29, 2, 0) },
              { type: 's', unknown: "\x00".b, rf_flags: 0x4,
                command: :set_temperature_mode,
                rf_address_to: 0x179101, room_id: 3,
                temperature: 24.0, mode: :vacation,
                datetime_until: Time.new(2016, 11, 29, 2, 30) },
              { type: 's', unknown: "\x00".b, rf_flags: 0x4,
                command: :set_temperature_mode,
                rf_address_from: 0x01, rf_address_to: 0x179101, room_id: 3,
                temperature: 24.5, mode: :vacation,
                datetime_until: Time.new(2016, 11, 29, 2, 29) },
              { type: 's', unknown: "\x00".b, rf_flags: 0x3,
                command: :set_temperature_mode,
                rf_address_from: 0x01, rf_address: 0x179101, room_id: 3,
                temperature: 24.5, mode: :vacation,
                datetime_until: Time.new(2016, 1, 29, 10, 59) },
              { type: 's', unknown: "\x00".b, rf_flags: 0x0,
                command: :set_temperature_mode,
                rf_address: 0x0fdaed, room_id: 1,
                temperature: 19.0, mode: :boost, },
              { type: 's', unknown: "\x00".b,
                command: :set_temperature_mode,
                rf_address: 0x122b65, room_id: 1,
                temperature: 19.0, mode: :manual, },
              { type: 's', unknown: "\x00".b,
                command: :set_temperature_mode,
                rf_address: 0x122b65, room_id: 1,
                temperature: 0.0, mode: :auto, },
              { type: 's', unknown: "\x00".b,
                command: :set_temperature_mode,
                rf_address: 0x122b65, room_id: 1,
                temperature: 29.5, mode: :vacation,
                datetime_until: Time.new(2015, 12, 15, 23, 00) },
            ]
          end
          let(:ret) do
            [
              's:AARAAAAAB5EAAWY=',
              's:' + Base64.strict_encode64("\x00\x04\x40\x00\x00\x04\x07\x91\x00\x01\xa6\x9d\x0b\x04"),
              's:' + Base64.strict_encode64("\x00\x04\x40\x00\x00\x04\x07\x91\x00\x01\xa6\x9d\x0b\x04"),
              's:' + Base64.strict_encode64("\x00\x04\x40\x00\x00\x00\x17\x91\x01\x03\xa6\xbd\x8f\x04"),
              's:' + Base64.strict_encode64("\x00\x04\x40\x00\x00\x00\x17\x91\x01\x03\xb0\xbd\x90\x05"),
              's:' + Base64.strict_encode64("\x00\x04\x40\x00\x00\x01\x17\x91\x01\x03\xb1\xbd\x90\x04"),
              's:' + Base64.strict_encode64("\x00\x03\x40\x00\x00\x01\x17\x91\x01\x03\xb1\x1d\x90\x15"),
              's:' + Base64.strict_encode64("\x00\x00\x40\x00\x00\x00\x0f\xda\xed\x01\xe6"),
              's:' + Base64.strict_encode64("\x00\x04\x40\x00\x00\x00\x12\x2b\x65\x01\x66"),
              's:' + Base64.strict_encode64("\x00\x04\x40\x00\x00\x00\x12\x2b\x65\x01\x00"),
              's:' + Base64.strict_encode64("\x00\x04\x40\x00\x00\x00\x12\x2b\x65\x01\xbb\xcf\x0f\x2e"),
            ].map { |s| s << "\r\n" }
          end
          it 'returns proper string' do
            hashes.each_with_index do |h, i|
              expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
            end
          end
        end
      end
      context 'set program' do
        context 'invalid hash body' do
          let(:hashes) do
            [
              # invalid values
              { type: 's',
                command: :set_program,
                rf_address: 0x122b65, room_id: 'x',
                day: 'Tuesday', program: [],
              },
              { type: 's',
                command: :set_program,
                rf_address: 0x122b65, room_id: '1',
                day: 'TuesdayX', program: [],
              },
              { type: 's',
                command: :set_program,
                rf_address: 0x122b65, room_id: '1',
                day: '0', program: [],
              },
              { type: 's',
                command: :set_program,
                rf_address: 0x122b65, room_id: '1',
                day: '8', program: [],
              },
              { type: 's',
                command: :set_program,
                rf_address: 0x122b65, room_id: 1, day: 'Sunday',
                program: [{ temperature: 'x', hours_until: 6, minutes_until: 5, }],
              },
              { type: 's',
                command: :set_program,
                rf_address: 0x122b65, room_id: 1, day: 'Sunday',
                program: [{ temperature: 10, hours_until: 'x', minutes_until: 5, }],
              },
              { type: 's',
                command: :set_program,
                rf_address: 0x122b65, room_id: 1, day: 'Sunday',
                program: [{ temperature: 12, hours_until: 5, minutes_until: 'x', }],
              },
            ]
          end
          it 'raises proper exception' do
            hashes.each do |h|
              expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
            end
          end
        end
        context 'valid hash' do
          let(:hashes) do
            [
              { type: 's', unknown: "\x00".b,
                command: :set_program,
                rf_address: 0x0fc380, room_id: 1, day: 'monday',
                program: [
                  { temperature: '16.0', hours_until: 6, minutes_until: 5, },
                  { temperature: '19', hours_until: '9', minutes_until: '10', },
                  { temperature: 16, hours_until: '16', minutes_until: 55, },
                  { temperature: 19.0, hours_until: 24, minutes_until: '0', },
                  { temperature: 19.0, hours_until: 24, minutes_until: 0, },
                  { temperature: 19.0, hours_until: 24, minutes_until: 0, },
                  { temperature: 19.0, hours_until: 24, minutes_until: 0, },
                ],
              },
              { type: 's',
                command: :set_program,
                rf_address: 0x122b65, room_id: 1, day: 'Tuesday',
                program: [],
              },
              { type: 's',
                command: :set_program,
                rf_address: 0x122b65, room_id: 1, day: '2',
                program: [],
              },
              { type: 's', unknown: "\x00".b,
                command: :set_program,
                rf_address: 0x122b65, room_id: 1, day: 'Sunday',
                program: [{ temperature: 16.0, hours_until: 6, minutes_until: 5, }],
              },
            ]
          end
          let(:ret) do
            [
              's:AAQQAAAAD8OAAQJASUxuQMtNIE0gTSBNIA==',
              's:' + Base64.strict_encode64("\x00\x04\x10\x00\x00\x00\x12\x2b\x65\x01\x03"),
              's:' + Base64.strict_encode64("\x00\x04\x10\x00\x00\x00\x12\x2b\x65\x01\x03"),
              's:' + Base64.strict_encode64("\x00\x04\x10\x00\x00\x00\x12\x2b\x65\x01\x01\x40\x49"),
            ].map { |s| s << "\r\n" }
          end
          it 'returns proper string' do
            hashes.each_with_index do |h, i|
              expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
            end
          end
        end
      end
      context 'set temperature' do
        context 'invalid hash body' do
          let(:hashes) do
            [
              # invalid values
              { type: 's',
                command: :set_temperature,
                rf_address: 0x0fc380, room_id: 'x',
                comfort_temperature: 21.5,
                eco_temperature: 16.5,
                max_setpoint_temperature: 30.5,
                min_setpoint_temperature: 4.5,
                temperature_offset: 0.0,
                window_open_temperature: 12.0,
                window_open_duration: 15,
              },
              { type: 's',
                command: :set_temperature,
                rf_address: 0x0fc380, room_id: '0',
                comfort_temperature: 'x',
                eco_temperature: 16.5,
                max_setpoint_temperature: 30.5,
                min_setpoint_temperature: 4.5,
                temperature_offset: 0.0,
                window_open_temperature: 12.0,
                window_open_duration: 15,
              },
              { type: 's',
                command: :set_temperature,
                rf_address: 0x0fc380, room_id: 0,
                comfort_temperature: 21.5,
                eco_temperature: 16.5,
                max_setpoint_temperature: 30.5,
                min_setpoint_temperature: 4.5,
                temperature_offset: '0..0',
                window_open_temperature: 12.0,
                window_open_duration: 15,
              },
              { type: 's',
                command: :set_temperature,
                rf_address: 0x0fc380, room_id: 0,
                comfort_temperature: 21.5,
                eco_temperature: 16.5,
                max_setpoint_temperature: 30.5,
                min_setpoint_temperature: 4.5,
                temperature_offset: 0.0,
                window_open_temperature: 12.0,
                window_open_duration: 'x',
              },
            ]
          end
          it 'raises proper exception' do
            hashes.each do |h|
              expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
            end
          end
        end
        context 'valid hash' do
          let(:hashes) do
            [
              { type: 's', unknown: "\x00".b,
                command: :set_temperature,
                rf_address: 0x0fc380, room_id: 0,
                comfort_temperature: 21.5,
                eco_temperature: 16.5,
                max_setpoint_temperature: 30.5,
                min_setpoint_temperature: 4.5,
                temperature_offset: '0',
                window_open_temperature: '12.0',
                window_open_duration: '15',
              },
              { type: 's', unknown: "\x00".b,
                command: :set_temperature,
                rf_address: 0x122b65, room_id: '1',
                comfort_temperature: 1.0,
                eco_temperature: 2.0,
                max_setpoint_temperature: '4.0',
                min_setpoint_temperature: 3.0,
                temperature_offset: 5.0,
                window_open_temperature: 6.0,
                window_open_duration: 10,
              },
            ]
          end
          let(:ret) do
            [
              's:AAARAAAAD8OAACshPQkHGAM=',
              's:' + Base64.strict_encode64("\x00\x00\x11\x00\x00\x00\x12\x2b\x65\x01\x02\x04\x08\x06\x11\x0c\x02"),
            ].map { |s| s << "\r\n" }
          end
          it 'returns proper string' do
            hashes.each_with_index do |h, i|
              expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
            end
          end
        end
      end
      context 'config valve' do
        context 'invalid hash body' do
          let(:hashes) do
            [
              # invalid values
              { type: 's',
                command: :config_valve,
                rf_address: 0x0fc380, room_id: 'x',
                boost_duration: '5',
                valve_opening: '90.0',
                decalcification_day: '6',
                decalcification_hour: 12,
                max_valve_setting: 100.0,
                valve_offset: 0.0,
              },
              { type: 's',
                command: :config_valve,
                rf_address: 0x0fc380, room_id: '1',
                boost_duration: 'x',
                valve_opening: '90.0',
                decalcification_day: '6',
                decalcification_hour: 12,
                max_valve_setting: 100.0,
                valve_offset: 0.0,
              },
              { type: 's',
                command: :config_valve,
                rf_address: 0x0fc380, room_id: '1',
                boost_duration: '5',
                valve_opening: '90%',
                decalcification_day: '6',
                decalcification_hour: 12,
                max_valve_setting: 100.0,
                valve_offset: 0.0,
              },
              { type: 's',
                command: :config_valve,
                rf_address: 0x0fc380, room_id: '1',
                boost_duration: '5',
                valve_opening: '90.0',
                decalcification_day: 'x',
                decalcification_hour: 12,
                max_valve_setting: 100.0,
                valve_offset: 0.0,
              },
              { type: 's',
                command: :config_valve,
                rf_address: 0x0fc380, room_id: '1',
                boost_duration: '5',
                valve_opening: '90.0',
                decalcification_day: '1',
                decalcification_hour: 'x',
                max_valve_setting: 100.0,
                valve_offset: 0.0,
              },
              { type: 's',
                command: :config_valve,
                rf_address: 0x0fc380, room_id: '1',
                boost_duration: '5',
                valve_opening: '90.0',
                decalcification_day: '1',
                decalcification_hour: '1',
                max_valve_setting: '100%',
                valve_offset: 0.0,
              },
              { type: 's',
                command: :config_valve,
                rf_address: 0x0fc380, room_id: '1',
                boost_duration: '5',
                valve_opening: '90.0',
                decalcification_day: '1',
                decalcification_hour: '1',
                max_valve_setting: '100',
                valve_offset: '0%',
              },
            ]
          end
          it 'raises proper exception' do
            hashes.each do |h|
              expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
            end
          end
        end
        context 'valid hash' do
          let(:hashes) do
            [
              { type: 's', unknown: "\x00".b,
                command: :config_valve,
                rf_address: 0x0fc380, room_id: 1,
                boost_duration: '5',
                valve_opening: '90.0',
                decalcification_day: '6',
                decalcification_hour: 12,
                max_valve_setting: '100',
                valve_offset: 0.0,
              },
              { type: 's', unknown: "\x00".b,
                command: :config_valve,
                rf_address: 0x122b65, room_id: 1,
                boost_duration: 10,
                valve_opening: 80.0,
                decalcification_day: 'Tuesday',
                decalcification_hour: 2,
                max_valve_setting: 100.0,
                valve_offset: '0',
              },
            ]
          end
          let(:ret) do
            [
              's:AAQSAAAAD8OAATIM/wA=',
              's:' + Base64.strict_encode64("\x00\x04\x12\x00\x00\x00\x12\x2b\x65\x01\x50\x62\xff\x00"),
            ].map { |s| s << "\r\n" }
          end
          it 'returns proper string' do
            hashes.each_with_index do |h, i|
              expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
            end
          end
        end
      end
      context 'add/remove link partner' do
        context 'invalid hash body' do
          let(:hashes) do
            [
              # invalid values
              { type: 's',
                command: :add_link_partner,
                rf_address: 0x0fc373, room_id: 'x',
                partner_rf_address: 0x0fdaed,
                partner_type: :radiator_thermostat,
              },
              { type: 's',
                command: :add_link_partner,
                rf_address: 0x0fc373, room_id: '1',
                partner_rf_address: 'x0fdaed',
                partner_type: :radiator_thermostat,
              },
              { type: 's',
                command: :add_link_partner,
                rf_address: 0x0fc373, room_id: '1',
                partner_rf_address: '0x0fdaed',
                partner_type: :radiator_thermostatx,
              },
            ]
          end
          it 'raises proper exception' do
            hashes.each do |h|
              expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
            end
          end
        end
        context 'valid hash' do
          let(:hashes) do
            [
              { type: 's',
                command: :add_link_partner,
                rf_address: 0x0fc373, room_id: '0',
                partner_rf_address: '0x0fdaed',
                partner_type: 'radiator_thermostat',
              },
              { type: 's', unknown: "\x00".b,
                command: :remove_link_partner,
                rf_address: 0x0fc373, room_id: 0,
                partner_rf_address: 0x0fdaed,
                partner_type: :radiator_thermostat,
              },
            ]
          end
          let(:ret) do
            [
              's:AAAgAAAAD8NzAA/a7QE=',
              's:AAAhAAAAD8NzAA/a7QE=',
            ].map { |s| s << "\r\n" }
          end
          it 'returns proper string' do
            hashes.each_with_index do |h, i|
              expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
            end
          end
        end
      end
      context 'set/unset group address' do
        context 'invalid hash body' do
          let(:hashes) do
            [
              # invalid values
              { type: 's',
                command: :set_group_address,
                rf_address: 0x0fc380, room_id: 'x',
              },
            ]
          end
          it 'raises proper exception' do
            hashes.each do |h|
              expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
            end
          end
        end
        context 'valid hash' do
          let(:hashes) do
            [
              { type: 's',
                command: :set_group_address,
                rf_address: 0x0fc380, room_id: '1',
              },
              { type: 's', unknown: "\x00".b,
                command: :unset_group_address,
                rf_address: 0x0fc380, room_id: 1,
              },
            ]
          end
          let(:ret) do
            [
              's:AAAiAAAAD8OAAAE=',
              's:AAAjAAAAD8OAAAE=',
            ].map { |s| s << "\r\n" }
          end
          it 'returns proper string' do
            hashes.each_with_index do |h, i|
              expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
            end
          end
        end
      end
      context 'setting of current temperature display' do
        context 'invalid hash body' do
          let(:hashes) do
            [
              # invalid values
              { type: 's',
                command: :display_temperature,
                rf_address: 0x123abc, room_id: 'x',
                display_temperature: :measured,
              },
            ]
          end
          it 'raises proper exception' do
            hashes.each do |h|
              expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
            end
          end
        end
        context 'valid hash' do
          let(:hashes) do
            [
              { type: 's',
                command: :display_temperature,
                rf_address: 0x123abc, room_id: '0',
                display_temperature: :measured,
              },
              { type: 's', unknown: "\x00".b,
                command: :display_temperature,
                rf_address: 0x123abc, room_id: 0,
                display_temperature: 'configured',
              },
              { type: 's', unknown: "\x00".b,
                command: :display_temperature,
                rf_address: 0x123abc, room_id: 0,
              },
              { type: 's', unknown: "\x00".b,
                command: :display_temperature,
                rf_address: 0x123abc, room_id: 0,
                display_temperature: 'XXX',
              },
            ]
          end
          let(:ret) do
            [
              's:' + Base64.strict_encode64("\x00\x00\x82\x00\x00\x00\x12\x3a\xbc\x00\x04"),
              's:' + Base64.strict_encode64("\x00\x00\x82\x00\x00\x00\x12\x3a\xbc\x00\x00"),
              's:' + Base64.strict_encode64("\x00\x00\x82\x00\x00\x00\x12\x3a\xbc\x00\x00"),
              's:' + Base64.strict_encode64("\x00\x00\x82\x00\x00\x00\x12\x3a\xbc\x00\x00"),
            ].map { |s| s << "\r\n" }
          end
          it 'returns proper string' do
            hashes.each_with_index do |h, i|
              expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
            end
          end
        end
      end
    end

    # t:01,1,Dx1U
    describe 't message' do
      context 'invalid hash' do
        let(:hashes) do
          [
            # invalid values
            { type: 't', count: 'x', force: 0, rf_addresses: [] },
            { type: 't', count: '1', force: 'x', rf_addresses: [] },
            { type: 't', count: '1', force: 'true', rf_addresses: ['x'] },
            # count mismatch
            { type: 't', count: 2, force: 0, rf_addresses: [1] },
            # no devices
            { type: 't', count: 0, force: 0, rf_addresses: [] },
          ]
        end
        it 'raises proper exception' do
          hashes.each do |h|
            expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
          end
        end
      end
      context 'valid hash' do
        let(:hashes) do
          [
            { type: 't', count: 1, force: true, rf_addresses: [0x0f1d54], },
            { type: 't', count: 1, force: '0', rf_addresses: [0x0f1d54], },
            { type: 't', count: 1, force: 'false', rf_addresses: [0x0f1d54], },
          ]
        end
        let(:ret) do
          [
            't:01,1,Dx1U',
            't:01,0,Dx1U',
            't:01,0,Dx1U',
          ].map { |s| s << "\r\n" }
        end
        it 'returns proper string' do
          hashes.each_with_index do |h, i|
            expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
          end
        end
      end
    end

    # u:http://www.max-portal.elv.de:80
    describe 'u message' do
      context 'invalid hash' do
        let(:hashes) do
          [
            # invalid values
            { type: 'u', url: 'URL', port: 'x' },
          ]
        end
        it 'raises proper exception' do
          hashes.each do |h|
            expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
          end
        end
      end
      context 'valid hash' do
        let(:hashes) do
          [
            { type: 'u', url: 'http://www.max-portal.elv.de', port: 80, },
          ]
        end
        let(:ret) do
          [
            'u:http://www.max-portal.elv.de:80',
          ].map { |s| s << "\r\n" }
        end
        it 'returns proper string' do
          hashes.each_with_index do |h, i|
            expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
          end
        end
      end
    end

    # z:1e,G,01
    describe 'z message' do
      context 'invalid hash' do
        let(:hashes) do
          [
            # invalid values
            { type: 'z', time: 'x', scope: 'all' },
            { type: 'z', time: 1, scope: 'all', id: 'x' },
            { type: 'z', time: 1, scope: 'allx' },
          ]
        end
        it 'raises proper exception' do
          hashes.each do |h|
            expect{ serializer.serialize_tcp_hash(h) }.to raise_error Messages::InvalidMessageBody
          end
        end
      end
      context 'valid hash' do
        let(:hashes) do
          [
            { type: 'z', time: 30, scope: :group, id: 1, },
            { type: 'z', time: 33, scope: :room, id: 2, },
            { type: 'z', time: 24, scope: :all, },
            { type: 'z', time: 1, scope: :device, },
          ]
        end
        let(:ret) do
          [
            'z:1e,G,01',
            'z:21,G,02',
            'z:18,A',
            'z:01,D',
          ].map { |s| s << "\r\n" }
        end
        it 'returns proper string' do
          hashes.each_with_index do |h, i|
            expect(serializer.serialize_tcp_hash(h)).to eq(ret[i])
          end
        end
      end
    end

  end

end
