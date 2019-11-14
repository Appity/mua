RSpec.describe Mua::State do
  it 'has minimal defaults' do
    state = Mua::State.new

    expect(state.parser).to be(nil)
    expect(state.enter).to eq([ ])
    expect(state.leave).to eq([ ])
    expect(state.interpret).to eq([ ])
    expect(state.default).to eq([ ])
    expect(state.terminate).to eq([ ])
    expect(state.terminal?).to be(false)
  end

  it 'can be assigned a name' do
    state = Mua::State.new(:example)

    expect(state.name).to eq(:example)
  end

  it 'can be terminal if terminate is defined' do
    state = Mua::State.new

    state.terminate << true

    expect(state).to be_terminal
  end
end
