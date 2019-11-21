require_relative '../support/mock_stream'

RSpec.describe Mua::Interpreter do
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

  if (false)
    RegexpInterpreter = Mua::Interpreter.define do
    attr_reader :received
    
    state :initialized do
      interpret(/\AHELO\s+/) do |line|
        @received = [ :helo, line ]
      end
  
      interpret(/\AMAIL FROM:<([^>]+)>/) do |line|
        @received = [ :mail_from, line ]
      end
    end
  end
  
  class TrackingDelegate
    include TestTriggerHelper
    
    attr_accessor :attribute
    
    def method_no_args
      trigger(:method_no_args)
    end
  
    def method_with_args(arg1, arg2)
      trigger(:method_with_args, [ arg1, arg2 ])
    end
  end
  
  class AutomaticDelegate
    include TestTriggerHelper
  
    def enter_initialized!
      trigger(:enter_initialized)
    end
  end
  
  class LineInterpreter < Mua::Interpreter
    attr_reader :lines
    
    state :initialized do
      enter do
        @lines = [ ]
      end
    end
    
    parse(match: /\A.*?\r?\n/, chomp: true) do |data|
      data
    end
    
    default do |line|
      @lines << line
    end
  end
  
  class NullDelimitedInterpreter < LineInterpreter
    parse(match: /\A.*?\0/) do |data|
      data.sub(/\0\z/, '')
    end
  end
  
  class ExampleInterpreter < Mua::Interpreter
    include TestTriggerHelper
  
    attr_accessor :message
    attr_accessor :reply
    
    state :initialized do
      enter do
        trigger(:enter_initialized_state)
      end
      
      interpret(:start) do
        enter_state(:start)
      end
  
      interpret(:branch) do
        enter_state(:branch)
      end
  
      leave do
        trigger(:leave_initialized_state)
      end
    end
    
    state :start do
      interpret(:stop) do |message|
        self.message = message
        enter_state(:stop)
      end
    end
    
    state :branch do
      default do |reply|
        @reply = reply
      end
    end
    
    state :stop do
      terminate
    end
  end
  
  class InterpreterWithAccessor < Mua::Interpreter
    attr_accessor :example
  end

  class MinimalInterpreter < Mua::Interpreter
  end

  it 'can define an interpreter' do
    interpreter = Mua::Interpreter.new

    expect(interpreter.state).to eq(:initialized)
  end

  it 'starts out in the initialized state' do
    expect(MinimalInterpreter.states_empty?).to be(true)

    expect(MinimalInterpreter.states_defined).to contain_exactly(:initialized, :terminated) 

    expect(MinimalInterpreter.state_defined?(:initialized)).to be(true)
    expect(MinimalInterpreter.state_defined?(:terminated)).to be(true)
    expect(MinimalInterpreter.state_defined?(:unknown)).to be(false)

    expect(MinimalInterpreter.states_defined).to contain_exactly(:initialized, :terminated)

    interpreter = MinimalInterpreter.new

    expect(interpreter.state).to eq(:initialized)
    
    buffer = 'a'
    
    interpreter.parse(buffer)

    expect(buffer).to eq('')
  end
  
  it 'will forward calls to a delegate' do
    delegate = TrackingDelegate.new

    expect(delegate.triggered)

    interpreter = MinimalInterpreter.new(delegate: delegate)

    expect(delegate.attribute).to be(nil)
    expect(delegate.triggered[:method_no_args]).to be(false)
    expect(delegate.triggered[:method_with_args]).to be(false)

    interpreter.send(:delegate_call, :method_no_args)
    
    expect(delegate.triggered[:method_no_args]).to be(true)
    expect(delegate.triggered[:method_with_args]).to be(false)

    interpreter.send(:delegate_call, :method_with_args, 'one', :two)

    expect(delegate.triggered[:method_no_args]).to be(true)
    expect(delegate.triggered[:method_with_args]).to match_array([ 'one', :two ])
    
    interpreter.send(:delegate_call, :invalid_method)
    
    interpreter.send(:delegate_assign, :attribute, 'true')
 
    expect(delegate.attribute).to eq('true')
  end
  
  it 'can be stopped manually and will enter the terminated state' do
    interpreter = ExampleInterpreter.new
  
    expect(interpreter.state).to eq(:initialized)
    expect(interpreter.triggered[:enter_initialized_state]).to eq(true)
    expect(interpreter.triggered[:leave_initialized_state]).to eq(false)
    
    interpreter.interpret(:start)

    expect(interpreter.state).to eq(:start)
    
    expect(interpreter.triggered[:enter_initialized_state]).to eq(true)
    expect(interpreter.triggered[:leave_initialized_state]).to eq(true)
    
    interpreter.interpret(:stop, 'Stop message')

    expect(interpreter.message).to eq('Stop message')
    expect(interpreter.state).to eq(:terminated)
  end
  
  it 'can process line-delimited data' do
    interpreter = LineInterpreter.new()

    expect(interpreter.lines).to eq([ ])
    
    line = "EXAMPLE LINE\n"
    
    interpreter.process(line)

    expect(interpreter.lines[-1]).to eq('EXAMPLE LINE')
    expect(line).to eq('')
    
    line << "ANOTHER EXAMPLE LINE\r\n"
    
    interpreter.process(line)

    expect(interpreter.lines[-1]).to eq('ANOTHER EXAMPLE LINE')
    expect(line).to eq('')
    
    line << "LINE ONE\r\nLINE TWO\r\n"
    
    interpreter.process(line)

    expect(interpreter.lines[-2]).to eq('LINE ONE')
    expect(interpreter.lines[-1]).to eq('LINE TWO')
    expect(line).to eq('')
    
    line << 'INCOMPLETE LINE'
    
    interpreter.process(line)

    expect(interpreter.lines[-1]).to eq('LINE TWO')
    expect(line).to eq('INCOMPLETE LINE')
    
    line << "\r"
    
    interpreter.process(line)

    expect(interpreter.lines[-1]).to eq('LINE TWO')
    expect(line).to eq("INCOMPLETE LINE\r")
    
    line << "\n"
    
    interpreter.process(line)

    expect(interpreter.lines[-1]).to eq('INCOMPLETE LINE')
    expect(line).to eq('')
  end
  
  it 'can handle lines delimited in alternate forms' do
    interpreter = NullDelimitedInterpreter.new
    
    expect(interpreter.lines).to eq([ ])
    
    line = "TEST"
    
    interpreter.process(line)
    
    expect(interpreter.lines[-1]).to eq(nil)
    expect(line).to eq('TEST')
    
    line << "\0"

    interpreter.process(line)
    
    expect(interpreter.lines[-1]).to eq('TEST')
    expect(line).to eq('')
  end
  
  it 'can have rules defined by regular expression' do
    interpreter = RegexpInterpreter.new
    
    expect(interpreter.received).to be(nil)
    
    line = 'HELO example.com'
    
    interpreter.process(line)
    expect(line).to eq('')
    
    expect(interpreter.received).to match_array([ :helo, 'example.com' ])
    
    line = 'MAIL FROM:<example@example.com>'
    
    interpreter.process(line)
    expect(line).to eq('')

    expect(interpreter.received).to match_array([ :mail_from, 'example@example.com' ])
  end

  def test_default_handler_for_interpreter
    interpreter = ExampleInterpreter.new
    
    interpreter.interpret(:branch)
    
    assert_equal :branch, interpreter.state
    
    assert_equal true, interpreter.interpret(:random)
    
    assert_equal :branch, interpreter.state
    assert_nil interpreter.error
    
    assert_equal :random, interpreter.reply
  end

  it 'can define an error handler for invalid responses' do
    interpreter = ExampleInterpreter.new

    expect(interpreter.state).to eq(:initialized)
    
    interpreter.interpret(:invalid)
    
    expect(interpreter.state).to eq(:terminated)
    expect(interpreter).to be_error

    expect(interpreter.error.index(':initialized'))
    expect(interpreter.error.index(':invalid'))
  end
  
  it 'can define accessors to make internal state visible' do
    interpreter = InterpreterWithAccessor.new
    
    expect(interpreter.example).to be(nil)

    interpreter = InterpreterWithAccessor.new do |interpreter|
      interpreter.example = 'example'
    end

    expect(interpreter.example).to eq('example')
  end
  end
end