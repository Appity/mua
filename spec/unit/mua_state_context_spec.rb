RSpec.describe Mua::State::Context, type: :reactor do
  it 'represents a context used to persist information between states and state machines' do
    context = Mua::State::Context.new

    expect(context).to be
    expect(context.reactor).to be(nil)
    expect(context.input).to be(nil)
    expect(context.state).to eq(:initialize)
    expect(context).to_not be_terminated
  end

  it 'has a constructor that accepts a block for customization' do
    context = Mua::State::Context.new(input: :default, state: :none) do |c|
      c.reactor = reactor
      c.input = 'demo'
      c.state = :finished
    end

    expect(context).to be
    expect(context.reactor).to be(reactor)
    expect(context.input).to eq('demo')
    expect(context.state).to eq(:finished)
    expect(context).to_not be_terminated
  end

  it 'can have properties assigned directly' do
    context = Mua::State::Context.new

    context.reactor = reactor
    context.state = :initialized
    context.terminated!

    expect(context.reactor).to be(reactor)
    expect(context.state).to eq(:initialized)
    expect(context).to be_terminated
  end

  it 'can have boolean attributes defined' do
    class ExampleContext < Mua::State::Context
      attr_boolean :example
    end

    context = ExampleContext.new(input: %w[ example ])

    expect(context.input).to contain_exactly('example')
    expect(context.example?).to be(false)

    context.example = 'yes'

    expect(context.example?).to be(true)
  end

  it 'can have boolean attributes defined' do
    ExampleContext = Mua::State::Context.define(
      example: {
        boolean: true,
        default: false
      }
    )

    context = ExampleContext.new(input: %w[ example ])

    expect(context.input).to contain_exactly('example')
    expect(context.example?).to be(false)

    context.example = 'yes'

    expect(context.example?).to be(true)
  end

  it 'can have methods defined via a block' do
    defined = Mua::State::Context.define do
      def customized?
        true
      end
    end

    context = defined.new

    expect(context).to be_customized
  end

  it 'can be associated with an Async reactor' do
    executed = false
    
    Async do |reactor|
      context = Mua::State::Context.new(reactor: reactor)

      expect(context.reactor).to be(reactor)

      executed = true
    end

    expect(executed).to be(true)
  end

  it 'can emit state transitions' do
    context = Mua::State::Context.new

    transition = context.transition!(state: :finished)

    expect(transition).to be_kind_of(Mua::State::Transition)
    expect(transition.state).to eq(:finished)
    expect(transition.parent).to eq(nil)
  end

  context 'can quickly define variant contexts using define' do
    context_type = Mua::State::Context.define(
      :nil_value,
      fixed_value: true,
      with_proc: -> { [ ] },
      with_customization: {
        variable: :@customized
      }
    )

    it 'returns a class that can be instantiated' do
      expect(context_type).to be_kind_of(Class)
    end

    it 'returns a class that can be subclassed' do
      derived = context_type.define(
        extra_attribute: true
      )

      expect(derived).to be_kind_of(Class)

      context = derived.new

      expect(context.nil_value).to be(nil)
      expect(context.fixed_value).to be(true)
      expect(context.with_proc).to eq([ ])
      expect(context.with_customization).to be(nil)
      expect(context.extra_attribute).to be(true)
    end

    it 'creates instances with default values' do
      context = context_type.new

      expect(context).to be_kind_of(context_type)

      expect(context.nil_value).to be(nil)
      expect(context.fixed_value).to be(true)
      expect(context.with_proc).to eq([ ])
      expect(context.with_customization).to be(nil)
    end

    it 'has properties that can be modified' do
      context = context_type.new

      expect(context).to be_kind_of(context_type)

      context.nil_value = 'nil'
      context.fixed_value = 'fixed'
      context.with_proc = 'proc'
      context.with_customization = 'customization'

      expect(context.nil_value).to eq('nil')
      expect(context.fixed_value).to eq('fixed')
      expect(context.with_proc).to eq('proc')
      expect(context.with_customization).to eq('customization')
    end

    it 'can have values customized during object construction' do
      context = context_type.new(
        nil_value: 'not_nil',
        fixed_value: nil,
        with_proc: false,
        with_customization: '-'
      )

      expect(context.nil_value).to eq('not_nil')
      expect(context.fixed_value).to be(nil)
      expect(context.with_proc).to be(false)
      expect(context.with_customization).to eq('-')
    end
  end
end
