require 'ostruct'

RSpec.describe Mua::Message::DeliveryResult do
  describe 'can encapsulate an SMTP delivery attempt' do
    it 'that failed' do
      message = OpenStruct.new

      result = Mua::Message::DeliveryResult.new(
        id: 'c5dd3337-5213-4088-a5a4-c31c2ca6e834@example.com',
        message: message,
        result_code: 'SMTP_550',
        result_message: '5.7.1 Connection refused.',
        proxy_host: '172.16.1.2',
        proxy_port: '1080',
        target_host: '192.168.1.10',
        target_port: '25'
      )

      expect(result.message).to be(message)
      expect(result.id).to eq('c5dd3337-5213-4088-a5a4-c31c2ca6e834@example.com')
      expect(result.result_code).to eq('SMTP_550')
      expect(result.result_message).to eq('5.7.1 Connection refused.')
      expect(result.proxy_host).to eq('172.16.1.2')
      expect(result.proxy_port).to eq(1080)
      expect(result.target_host).to eq('192.168.1.10')
      expect(result.target_port).to eq(25)
      expect(result.state).to eq(:queued)
    end

    it 'that succeeded' do
      message = OpenStruct.new

      result = Mua::Message::DeliveryResult.new(
        message: message,
        id: 'c5dd3337-5213-4088-a5a4-c31c2ca6e834@example.com',
        result_code: 'SMTP_250',
        result_message: 'OK',
        proxy_host: '172.16.1.2',
        proxy_port: '1080',
        target_host: '192.168.1.10',
        target_port: '25',
        state: :delivered
      )

      expect(result.message).to be(message)
      expect(result.id).to eq('c5dd3337-5213-4088-a5a4-c31c2ca6e834@example.com')
      expect(result.result_code).to eq('SMTP_250')
      expect(result.result_message).to eq('OK')
      expect(result.proxy_host).to eq('172.16.1.2')
      expect(result.proxy_port).to eq(1080)
      expect(result.target_host).to eq('192.168.1.10')
      expect(result.target_port).to eq(25)
      expect(result.state).to eq(:delivered)
    end
  end

  it 'will inherit the id from the message argument' do
    message = OpenStruct.new(
      id: 'c5dd3337-5213-4088-a5a4-c31c2ca6e834@example.com'
    )

    result = Mua::Message::DeliveryResult.new(message: message)

    expect(result.id).to eq(message.id)
  end
end
