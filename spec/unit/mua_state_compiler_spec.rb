RSpec.describe Mua::State::Compiler do
  context 'dispatcher()' do
    it 'can create a Proc based on an empty spec' do
      compiled = Mua::State::Compiler.dispatcher([ ])

      expect(compiled).to be_kind_of(Proc)

      context = Mua::State::Context.new

      expect(compiled.call(context, :test)).to be(nil)
    end

    it 'can create a Proc with branches' do
      compiled = Mua::State::Compiler.dispatcher([
        [ :a, -> (context) { context.visited = :a } ],
        [ :b, -> (context) { context.visited = :b } ]
      ])

      context = Mua::State::Context.define(:visited).new

      expect(compiled.call(context, :a)).to eq(:a)
      expect(context.visited).to eq(:a)

      expect(compiled.call(context, :b)).to eq(:b)
      expect(context.visited).to eq(:b)

      expect(compiled.call(context, :c)).to eq(nil)
      expect(context.visited).to eq(:b)
    end

    it 'can create a Proc with branches and a default' do
      compiled = Mua::State::Compiler.dispatcher(
        [
          [ :a, -> (context) { context.visited = :a } ],
          [ :b, -> (context) { context.visited = :b } ]
        ],
        -> (context, visited) { context.visited = { defaulted: visited } }
      )

      context = Mua::State::Context.define(:visited).new

      expect(compiled.call(context, :a)).to eq(:a)
      expect(context.visited).to eq(:a)

      expect(compiled.call(context, :b)).to eq(:b)
      expect(context.visited).to eq(:b)

      expect(compiled.call(context, :c)).to eq({ defaulted: :c })
      expect(context.visited).to eq({ defaulted: :c })
    end
    it 'can create a Proc with only a default' do
      compiled = Mua::State::Compiler.dispatcher(
        [ ],
        -> (context, visited) { context.visited = { defaulted: visited } }
      )
  
      context = Mua::State::Context.define(:visited).new
  
      expect(compiled.call(context, :a)).to eq({ defaulted: :a })
      expect(context.visited).to eq({ defaulted: :a })
  
      expect(compiled.call(context, :b)).to eq({ defaulted: :b })
      expect(context.visited).to eq({ defaulted: :b })
  
      expect(compiled.call(context, :c)).to eq({ defaulted: :c })
      expect(context.visited).to eq({ defaulted: :c })
    end
  end
end
