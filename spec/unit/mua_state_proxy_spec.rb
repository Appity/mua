RSpec.describe Mua::State::Proxy do
  it 'can be attached to a State' do
    state = Mua::State.new
    proxy = Mua::State::Proxy.new(state)
  end
  
  it 'provides access to properties in the State' do
    state = Mua::State.new
    proxy = Mua::State::Proxy.new(state)

    proxy.parse do |stream|
      stream.read
    end

    proxy.enter do
      :enter
    end

    proxy.leave do
      :leave
    end

    proxy.default do
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

    expect(state.parser).to be_kind_of(Proc)
    expect(state.enter).to be_an_array_of(Proc)
    expect(state.leave).to be_an_array_of(Proc)
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
end
