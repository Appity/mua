require_relative '../support/mock_stream'

RSpec.describe Mua::Interpreter, type: [ :interpreter, :reactor ] do
  context 'define' do
    it 'can create a class with a custom state machine and context' do
      interpreter_class = Mua::Interpreter.define(
        header: nil,
        body: -> { [ ] }
      ) do
        parser(match: "\n", chomp: true)

        state(:initialize) do
          enter do |context|
            context.transition!(state: :header)
          end
        end

        state(:header) do
          default do |context, line|
            context.header = line.split('|')

            context.transition!(state: :body)
          end
        end

        state(:body) do
          default do |context, line|
            context.body << line.split('|')
          end
        end
      end

      expect(interpreter_class.superclass).to be(Mua::Interpreter)
      expect(interpreter_class.context.superclass).to be(Mua::State::Context)
      expect(interpreter_class.machine).to be_kind_of(Mua::State::Machine)

      data = %w[
        a|b|c
        1|2|3
        4|5|6
        7|8|9
        *|0|#
      ]

      interpreter = interpreter_class.new(MockStream.new(data.join("\n") + "\n"))

      context = interpreter.context
      expect(context).to be_kind_of(interpreter_class.context)
      expect(context).to respond_to(:header=, :body)

      interpreter.run!

      expect(context.header).to eq(%w[ a b c ])
      expect(context.body).to match_array(data[1..4].map{ |v| v.split('|') })
    end
  end

  context 'handles line-based protocols' do
    RegexpInterpreter = Mua::Interpreter.define(received: -> { [ ] }) do
      parser(line: true, separator: "\r\n")

      state(:initialize) do
        enter do |context|
          context.transition!(state: :helo)
        end
      end

      state(:helo) do
        interpret(/\AHELO\s+(.*)\z/) do |context, _, host|
          context.received << [ :helo, host ]
          context.input.puts('250 Hi')

          context.transition!(state: :mail_from)
        end
      end

      state(:mail_from) do
        interpret(/\AMAIL FROM:\<([^>]+)\>\z/) do |context, _, addr|
          context.received << [ :mail_from, addr ]
          context.input.puts('250 Continue')
        end
      end

      interpret(/\AQUIT\z/) do |context|
        context.received << [ :quit ]
        context.input.puts('221 Later')

        context.transition!(state: :finished)
      end

      default do |context, input|
        context.received << [ :error, input ]
        context.input.puts('550 Invalid')
      end
    end

    it 'will run through a simple SMTP-style echange' do
      context, io = MockStream.context_writable_io(RegexpInterpreter.context)

      expect(context).to be_kind_of(RegexpInterpreter.context)
      expect(io).to be_kind_of(Async::IO::Stream)
      expect(context.received).to eq([ ])

      io.puts('HELO example.com')
      io.puts('MAIL FROM:<test@example.com>')
      io.puts('QUIT')
      io.close_write

      interpreter = RegexpInterpreter.new(context)

      expect(interpreter.machine.states[:initialize].parent).to be(interpreter.machine)
      expect(interpreter.machine.states[:helo].parent).to be(interpreter.machine)
      
      expect(interpreter.context).to be(context)

      interpreter_run!(interpreter)

      expect(context.received).to eq([
        [ :helo, 'example.com' ],
        [ :mail_from, 'test@example.com' ],
        [ :quit ]
      ])
    end
  end
end
