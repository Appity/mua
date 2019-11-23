require 'async/io'
require 'async/rspec'

require_relative '../support/smtp_delegate'
require_relative '../support/mock_stream'

RSpec.describe Mua::SMTP::Client::Interpreter, type: [ :interpreter, :reactor ], timeout: 5 do
  Context = Mua::SMTP::Client::Context
  Interpreter = Mua::SMTP::Client::Interpreter

  it 'defines a context type' do
    expect(Interpreter.context).to be(Context)

    expect(Interpreter.new(nil).context).to be_kind_of(Context)
  end

  it 'starts out in the initailized state' do
    context = Interpreter.context.new

    expect(context.state).to eq(:initialize)
  end

  it 'supports standard SMTP connections' do
    with_interpreter(Interpreter) do |context, io|
      io.puts('220 mail.example.com SMTP Example')
      expect(io.gets).to eq('HELO localhost')

      io.puts('420 Go away')
      expect(io.gets).to eq('QUIT')

      io.close
    end
  end

  context 'has pre-defined SMTP dialog tests' do
    Dir.glob(File.expand_path('../smtp/dialog/*.yml', __dir__)).each do |path|
      script = YAML.load(File.open(path))

      tags = [ *script['tags'] ].compact.map do |tag|
        [ tag.to_sym, true ]
      end.to_h

      it(script['name'] || File.basename(path, '.yml').gsub('-', ' '), dynamic: true, **tags) do
        with_interpreter(Interpreter) do |context, io|
          io.run_dialog(self, script)
        end
      end
    end
  end
end
