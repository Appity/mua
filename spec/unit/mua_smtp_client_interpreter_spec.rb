require 'async/io'
require 'async/rspec'

require_relative '../support/smtp_delegate'
require_relative '../support/mock_stream'

RSpec.describe Mua::SMTP::Client::Interpreter, type: [ :interpreter, :reactor ], timeout: 1 do
  ClientContext = Mua::Client::Context
  ClientInterpreter = Mua::SMTP::Client::Interpreter

  it 'defines a context type' do
    expect(ClientInterpreter.context).to be(ClientContext)

    context = ClientInterpreter.new(nil).context

    expect(context).to be_kind_of(ClientContext)
    expect(context.state).to eq(:smtp_connect)
  end

  it 'defines a state machine' do
    expect(ClientInterpreter.machine).to be_kind_of(Mua::State::Machine)
  end

  it 'starts out in the initailized state' do
    context = ClientInterpreter.context.new

    expect(context.state).to eq(:initialize)
  end

  it 'supports standard SMTP connections' do
    with_interpreter(ClientInterpreter) do |context, io|
      expect(context.state).to eq(:smtp_connect)
      io.puts('220 mail.example.com SMTP Example')
      expect(io.gets).to eq('HELO localhost')

      io.puts('420 Go away')
      expect(io.gets).to eq('QUIT')

      io.close_write
    end
  end

  context 'has pre-defined SMTP dialog tests' do
    Dir.glob(File.expand_path('../smtp/client-dialog/*.yml', __dir__)).each do |path|
      script = YAML.load(File.open(path))

      tags = [ *script['tags'] ].compact.map do |tag|
        [ tag.to_sym, true ]
      end.to_h

      it(script['name'] || File.basename(path, '.yml').gsub('-', ' '), dynamic: true, **tags) do
        with_interpreter(ClientInterpreter) do |context, io|
          io.run_dialog(self, script)
        end
      end
    end
  end
end
