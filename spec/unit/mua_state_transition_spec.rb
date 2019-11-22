RSpec.describe Mua::State::Transition do
  it 'can designate a desired state' do
    transition = Mua::State::Transition.new(state: :finished)

    expect(transition.state).to eq(:finished)
    expect(transition.parent).to be(nil)
  end

  it 'can a desired state with parent jump disabled' do
    transition = Mua::State::Transition.new(state: :finished, parent: false)

    expect(transition.state).to eq(:finished)
    expect(transition.parent).to eq(false)
  end
end
