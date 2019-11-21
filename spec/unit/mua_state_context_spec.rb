RSpec.describe Mua::State::Context do
  it 'represents a context used to persist information between states and state machines' do
    context = Mua::State::Context.new

    expect(context).to be
    expect(context.task).to be(nil)
    expect(context.input).to be(nil)
    expect(context.state).to eq(:initialize)
    expect(context).to_not be_terminated
  end

  it 'has a constructor that accepts a block for customization' do
    Async do |task|
      context = Mua::State::Context.new(input: :default, state: :none) do |c|
        c.task = task
        c.input = 'demo'
        c.state = :finished
      end

      expect(context).to be
      expect(context.task).to be(task)
      expect(context.input).to eq('demo')
      expect(context.state).to eq(:finished)
      expect(context).to_not be_terminated
    end
  end

  it 'can have properties assigned directly' do
    Async do |task|
      context = Mua::State::Context.new

      context.task = task
      context.state = :initialized
      context.terminated!

      expect(context.task).to be(task)
      expect(context.state).to eq(:initialized)
      expect(context).to be_terminated
    end
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

  it 'can have boolean attributes defined through with_attributes' do
    ExampleContext = Mua::State::Context.with_attributes(
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
    defined = Mua::State::Context.with_attributes do
      def customized?
        true
      end
    end

    context = defined.new

    expect(context).to be_customized
  end

  it 'can be associated with an Async task' do
    executed = false
    
    Async do |task|
      context = Mua::State::Context.new(task: task)

      expect(context.task).to be(task)

      executed = true
    end

    expect(executed).to be(true)
  end

  it 'can emit state transitions' do
    context = Mua::State::Context.new

    transition = context.transition!(target: :example, state: :finished)

    expect(transition).to be_kind_of(Mua::State::Transition)
    expect(transition.target).to eq(:example)
    expect(transition.state).to eq(:finished)
  end

  context 'can quickly define variant contexts using with_attributes' do
    context_type = Mua::State::Context.with_attributes(
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
