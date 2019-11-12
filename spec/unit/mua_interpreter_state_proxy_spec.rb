RSpec.describe Mua::Interpreter::StateProxy do
  it 'has minimal defaults' do
    options = { }
    
    Mua::Interpreter::StateProxy.new(options)

    expect(options).to eq({ })
  end
  
  it 'can take a simple configuration' do
    options = { }
    
    proxy = Mua::Interpreter::StateProxy.new(options)

    expected = {
      enter: [ -> { } ],
      default: [ -> { } ],
      leave: [ -> { } ]
    }.freeze

    proxy.enter(&expected[:enter][0])
    proxy.default(&expected[:default][0])
    proxy.leave(&expected[:leave][0])
    
    expect(options).to eq(expected)
  end

  it 'can redefine the terminal condition' do
    options = { }

    expected = {
      enter: [ -> { } ],
      terminate: [ -> { } ],
      leave: [ -> { } ]
    }.freeze

    Mua::Interpreter::StateProxy.new(options) do
      enter(&expected[:enter][0])
      terminate(&expected[:terminate][0])
      leave(&expected[:leave][0])
    end

    expect(options).to eq(expected)
  end

  it 'can accept a simple interpreter argument' do
    options = { }
    
    expected = {
      enter: [ -> { } ],
      interpret: [ [ 10, -> { } ], [ 1, -> { } ] ],
      default: [ -> { } ],
      leave: [ -> { } ]
    }.freeze

    Mua::Interpreter::StateProxy.new(options) do
      enter(&expected[:enter][0])
      interpret(10, &expected[:interpret][0][1])
      interpret(1, &expected[:interpret][1][1])
      default(&expected[:default][0])
      leave(&expected[:leave][0])
    end

    expect(options).to eq(expected)
  end

  it 'can have options rebound' do
    options_a = { }
    options_b = { }
    
    proc = [ -> { }, -> { } ]
    
    proxy = Mua::Interpreter::StateProxy.new(options_a) do
      enter(&proc[0])
    end
    
    proxy.send(:rebind, options_b)
    
    proxy.leave(&proc[1])
    
    expect(options_a).to eq({ enter: [ proc[0] ] })
    expect(options_b).to eq({ leave: [ proc[1] ] })
  end
end
