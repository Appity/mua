RSpec.describe Mua::State::Proxy do
  it 'can be attached to a State' do
    state = Mua::State.new
    proxy = Mua::State::Proxy.new(state)
  end
  
  it 'provides access to properties in the State' do
    state = Mua::State.new
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

    proxy.terminate do
      :terminate
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
    expect(state.terminate).to be_an_array_of(Proc)
    expect(state).to be_terminal
  end

  it 'can redefine the terminal condition' do
    state = Mua::State.new 
    proxy = Mua::State::Proxy.new(state) do
      terminate
    end

    expect(state.terminate).to match_array([ true ])
    expect(state).to be_terminal
  end

  it 'can define sub-states' do
    parent = Mua::State.new 
    substate = nil

    proxy = Mua::State::Proxy.new(parent) do |p|
      substate = p.state(:example) do |s|
        s.enter do |context|
          context.transition!(state: :finished)
        end
      end
    end

    expect(substate).to be_kind_of(Mua::State)
    expect(substate.parent).to be(parent)
  end
end
