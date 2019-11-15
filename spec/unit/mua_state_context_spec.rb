RSpec.describe Mua::State::Context do
  it 'represents a context used to persist information between states and state machines' do
    context = Mua::State::Context.new

    expect(context).to be
    expect(context.task).to be(nil)
    expect(context.state).to be(nil)
    expect(context).to_not be_terminated
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

    context = ExampleContext.new

    expect(context.example?).to be(false)

    context.example = 'yes'

    expect(context.example?).to be(true)
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

      context = context_type.new

      expect(context).to be_kind_of(context_type)

      expect(context.nil_value).to be(nil)
      expect(context.fixed_value).to be(true)
      expect(context.with_proc).to eq([ ])
      expect(context.with_customization).to be(nil)
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

  context 'can define boolean attributes with ?-style interrogators' do
    context_type = Mua::State::Context.with_attributes(
      boolean_value: {
        boolean: true,
        default: false
      }
    )

    it 'properly defaults' do
      context = context_type.new

      expect(context).to_not be_boolean_value
    end

    it 'accepts overrides on initialize' do
      context = context_type.new(boolean_value: true)

      expect(context).to be_boolean_value
    end

    it 'accepts input and modifications' do
      context = context_type.new(boolean_value: true)

      context.boolean_value = false

      expect(context).to_not be_boolean_value
    end

    it 'converts input values to booleans' do
      context = context_type.new(boolean_value: nil)

      expect(context).to_not be_boolean_value

      context.boolean_value = false

      expect(context).to_not be_boolean_value

      context.boolean_value = 'yes'

      expect(context).to be_boolean_value
    end

    it 'implements a quick switcher with ! postfix' do
      context = context_type.new

      expect(context.boolean_value!).to be(true)

      expect(context.boolean_value!).to be(false)
    end

    it 'executes blocks only if not set' do
      context = context_type.new
      executed = 0

      expect(context).to_not be_boolean_value
      expect(executed).to eq(0)

      context.boolean_value! do
        executed += 1
      end

      expect(context).to be_boolean_value
      expect(executed).to eq(1)

      context.boolean_value! do
        executed += 1
      end

      expect(context).to be_boolean_value
      expect(executed).to eq(1)
    end
  end
end
