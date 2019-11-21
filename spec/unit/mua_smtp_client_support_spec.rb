RSpec.describe Mua::SMTP::Client::Support do
  it 'can split simple replies' do
    expect_mapping(
      '250 OK' => [ 250, 'OK' ],
      '250 Long message' => [ 250, 'Long message' ],
      'OK' => nil,
      '100-Example' => [ 100, 'Example', :continued ]
    ) do |reply|
      Mua::SMTP::Client::Support.unpack_reply(reply)
    end
  end

  it 'can encode for DATA by avoiding single dot lines' do
    sample_data = "Line 1\r\nLine 2\r\n.\r\nLine 3\r\n.Line 4\r\n".freeze
    
    expect(Mua::SMTP::Client::Support.encode_data(sample_data)).to eq("Line 1\r\nLine 2\r\n..\r\nLine 3\r\n..Line 4\r\n")
  end

  it 'can decode Base64-encoded content with Interpreter#base64' do
    expect_mapping(
      'example' => 'example',
      "\x7F" => "\x7F",
      nil => ''
    ) do |example|
      Mua::SMTP::Client::Support.base64(example).unpack('m')[0]
    end
  end
  
  it '#encode_authentication can encode username/password pairs correctly' do
    expect_mapping(
      %w[ tester tester ] => 'AHRlc3RlcgB0ZXN0ZXI=',
      %w[ username password ] => 'AHVzZXJuYW1lAHBhc3N3b3Jk'
    ) do |username, password|
      Mua::SMTP::Client::Support.encode_auth(username, password)
    end
  end
end
