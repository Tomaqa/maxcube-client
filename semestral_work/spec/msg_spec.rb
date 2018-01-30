require_relative '../messages'
require_relative 'spec_helper'

describe 'MessageReceiver' do
  subject(:recv) { MaxCube::MessageReceiver.new }
  # let(:game) do
  #   '003020600900305001001806400008102900700' \
  #   '000008006708200002609500800203009005010300'
  # end

  describe 'invalid message' do
    context 'empty message' do
      it 'raises proper exception' do
        expect { recv.recv_data('') }.to raise_error MaxCube::MessageHandler::InvalidMessageEmpty
      end
    end

    context 'invalid type' do
      let(:inputs) do
        [
          nil,
          0,
          1,
          1.5,
          /abc/,
          Object.new,
          [],
          {},
        ]
      end
      it 'raises proper exception' do
        inputs.each do |inp|
          expect { recv.recv_data(inp) }.to raise_error TypeError
        end
      end
    end

    context 'invalid format' do
      context 'of single message' do
        let(:msgs) do
          [
            ':',
            '::',
            'H::',
            'H:X:',
            'HX:',
            'HX:A',
            'HX:A:',
            '1:',
          ]
        end
        it 'raises proper exception and #valid_recv_msg is falsey' do
          msgs.each do |m|
            expect { recv.recv_data(m) }.to raise_error MaxCube::MessageHandler::InvalidMessageFormat
            expect(recv.valid_recv_msg(m)).to be_falsey
          end
        end
      end

      context 'of raw data' do
        let(:data) do
          [
            "A:\r\naX:",
            "A:\r\nA:\r\naX:",
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
  end
end
