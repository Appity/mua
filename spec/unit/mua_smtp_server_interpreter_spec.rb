require 'async/io'
require 'async/rspec'

require_relative '../support/smtp_delegate'
require_relative '../support/mock_stream'

RSpec.describe Mua::SMTP::Server::Interpreter, type: [ :interpreter, :reactor ], timeout: 1 do
  ServerContext = Mua::SMTP::Server::Context
  ServerInterpreter = Mua::SMTP::Server::Interpreter

  it 'defines a context type' do
    expect(ServerInterpreter.context).to be(ServerContext)

    expect(ServerInterpreter.new(nil).context).to be_kind_of(ServerContext)
  end

  it 'starts out in the initailized state' do
    context = ServerInterpreter.context.new

    expect(context.state).to eq(:initialize)
  end

  context 'has pre-defined SMTP dialog tests' do
    Dir.glob(File.expand_path('../smtp/server-dialog/*.yml', __dir__)).each do |path|
      script = YAML.load(File.open(path))

      tags = [ *script['tags'] ].compact.map do |tag|
        [ tag.to_sym, true ]
      end.to_h

      it(script['name'] || File.basename(path, '.yml').gsub('-', ' '), dynamic: true, **tags) do
        with_interpreter(ServerInterpreter) do |context, io|
          context.assign_remote_ip!
          context.assign_local_ip!
          
          io.run_dialog(self, script)
        end
      end
    end
  end
end
