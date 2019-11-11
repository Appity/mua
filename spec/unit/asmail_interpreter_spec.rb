RSpec.describe ASMail::Interpreter do
  it 'can define an interpreter' do
    interpreter = ASMail::Interpreter.new

    expect(interpreter.state).to eq(:initialized)
  end
end
