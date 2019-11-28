RSpec.describe Mua::Token do
  it 'represents a discrete value' do
    a = Mua::Token.new('a')
    b = Mua::Token.new('b')

    expect(a).to_not eq(b)
    expect(a).to eq(a)

    a2 = Mua::Token.new('a')

    expect(a).to_not eq(a2)
  end
  
  it 'can be used in a case statement' do
    a = Mua::Token.new('a')
    b = Mua::Token.new('b')

    branch = 
      case (a)
      when a
        :a
      when b
        :b
      end

    expect(branch).to eq(:a)

    branch = 
      case (b)
      when a
        :a
      when b
        :b
      end

    expect(branch).to eq(:b)
  end

  it 'has an inspect value' do
    a = Mua::Token.new('a')

    expect(a.inspect).to eq('<Mua::Token(a)>')
  end
end
