RSpec.describe Mua::State::Transition do
  it 'can designate a desired state' do
    transition = Mua::State::Transition.new(state: :finished)

    expect(transition.target).to be(nil)
    expect(transition.state).to eq(:finished)
  end

  it 'can designate a target and a desired state' do
    transition = Mua::State::Transition.new(target: :example, state: :finished)

    expect(transition.target).to eq(:example)
    expect(transition.state).to eq(:finished)
  end
end
