RSpec.describe Mua::State::Proxy, type: :reactor, timeout: 1 do
  it 'can be attached to a State' do
    state = Mua::State.new
    proxy = Mua::State::Proxy.new(state)
  end
  
  it 'provides access to properties in the State' do
    state = Mua::State.new do |state|
      proxy = Mua::State::Proxy.new(state)

      proxy.preprocess do |context|
        context.tag << :preprocess
      end

      proxy.parser do |context|
        context.input.read
      end

      proxy.enter do |_context|
        :enter
      end

      proxy.leave do |_context|
        :leave
      end

      proxy.default do |_context|
        :default
      end

      proxy.interpret('a') do
        :a
      end

      proxy.interpret('b') do
        :b
      end
    end

    expect(state.preprocess).to be_kind_of(Proc)
    expect(state.preprocess.arity).to eq(1)
    expect(state.parser).to be_kind_of(Proc)
    expect(state.parser.arity).to eq(1)
    expect(state.enter).to be_an_array_of(Proc)
    expect(state.enter.map(&:arity)).to contain_exactly(1)
    expect(state.leave).to be_an_array_of(Proc)
    expect(state.leave.map(&:arity)).to contain_exactly(1)
    expect(state.default).to be_kind_of(Proc)
    expect(state.interpret).to be_an_array_of(Array)
    expect(state.interpret.length).to eq(2)
  end

  it 'can define sub-states' do
    substate = nil
    parent = Mua::State.new do |parent|
      proxy = Mua::State::Proxy.new(parent) do |p|
        substate = p.state(:example) do |s|
          s.enter do |context|
            context.transition!(state: :finished)
          end
        end
      end
    end

    expect(substate).to be_kind_of(Mua::State)
    expect(substate.parent).to be(parent)
  end

  it 'can define one or more terminal states' do
    machine = Mua::State::Machine.new(
      name: 'TerminalTest',
      auto_terminate: false
    ) do |machine|
      proxy = Mua::State::Proxy.new(machine)

      proxy.parser do |context|
        context.input.shift
      end

      proxy.state(:initialize) do
        interpret(:a) do |context|
          context.transition!(state: :a)
        end

        interpret(:b) do |context|
          context.transition!(state: :b)
        end
      end

      proxy.state(:a, terminal: true)
      proxy.state(:b)
    end

    expect(machine).to be_kind_of(Mua::State::Machine)
    expect(machine).to_not be_auto_terminate

    context = Mua::State::Context.new(input: [ :a ])

    machine.run(context) do |context, state, *ev|
      # p(context: context.object_id, state: state.name, event: ev, terminated: context.terminated?)
    end

    expect(context.state).to eq(:a)
    expect(context).to be_terminated

    context = Mua::State::Context.new(input: [ :b ])

    machine.run(context) do |context, state, *ev|
      # p(context: context.object_id, state: state.name, event: ev, terminated: context.terminated?)
    end

    expect(context.state).to eq(:b)
    expect(context).to_not be_terminated
  end
end
