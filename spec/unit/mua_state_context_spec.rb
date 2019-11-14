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
end
