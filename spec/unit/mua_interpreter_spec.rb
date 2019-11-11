RSpec.describe Mua::Interpreter do
  it 'can define an interpreter' do
    interpreter = Mua::Interpreter.new

    expect(interpreter.state).to eq(:initialized)
  end
end
