require 'ostruct'

RSpec.describe Mua::Client::DeliveryResult do
  it 'can encapsulate an SMTP delivery attempt' do
    message = OpenStruct.new

    result = Mua::Client::DeliveryResult.new(
      message: message,
      result_code: 'SMTP_550',
      result_message: '5.7.1 Connection refused.',
      proxy_host: '172.16.1.2',
      proxy_port: '1080',
      target_host: '192.168.1.10',
      target_port: '25',
      delivered: false
    )

    expect(result.message).to be(message)
    expect(result.result_code).to eq('SMTP_550')
    expect(result.result_message).to eq('5.7.1 Connection refused.')
    expect(result.proxy_host).to eq('172.16.1.2')
    expect(result.proxy_port).to eq(1080)
    expect(result.target_host).to eq('192.168.1.10')
    expect(result.target_port).to eq(25)
    expect(result).to_not be_delivered
  end

  it 'can encapsulate an SMTP delivery success' do
    message = OpenStruct.new

    result = Mua::Client::DeliveryResult.new(
      message: message,
      result_code: 'SMTP_250',
      result_message: 'OK',
      proxy_host: '172.16.1.2',
      proxy_port: '1080',
      target_host: '192.168.1.10',
      target_port: '25',
      delivered: true
    )

    expect(result.message).to be(message)
    expect(result.result_code).to eq('SMTP_250')
    expect(result.result_message).to eq('OK')
    expect(result.proxy_host).to eq('172.16.1.2')
    expect(result.proxy_port).to eq(1080)
    expect(result.target_host).to eq('192.168.1.10')
    expect(result.target_port).to eq(25)
    expect(result).to be_delivered
  end
end
