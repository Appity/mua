RSpec.describe Mua::State::Context do
  it 'represents a context used to persist information between states and state machines' do
    context = Mua::State::Context.new

    expect(context).to be
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
end
