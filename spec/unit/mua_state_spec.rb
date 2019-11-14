RSpec.describe Mua::State do
  it 'has minimal defaults' do
    state = Mua::State.new

    expect(state.parser).to be(nil)
    expect(state.enter).to eq([ ])
    expect(state.leave).to eq([ ])
    expect(state.interpret).to eq([ ])
    expect(state.default).to be(nil)
    expect(state.terminate).to eq([ ])
    expect(state.terminal?).to be(false)
  end

  it 'can be assigned a name' do
    state = Mua::State.new(:example)

    expect(state.name).to eq(:example)
  end

  it 'can have handlers populated manually' do
    state = Mua::State.new
    ran = [ ]

    state.parser = -> (context, input) {
      ran << :parser

      input.to_s
    }
    state.enter << -> (context) { ran << :enter }
    state.leave << -> (context) { ran << :leave }
    state.interpret << [ 'example', -> (context) { ran << :example } ]
    state.default = -> (context) { ran << :default }
    state.terminate << -> (context) { ran << :terminate }

    context = Mua::State::Context.new
    state.call(context, :example).to_a

    expect(ran).to contain_exactly(:parser, :enter, :example, :leave, :terminate)

    ran.clear

    state.call(context, :not_example).to_a

    expect(ran).to contain_exactly(:parser, :enter, :default, :leave, :terminate)
  end

  it 'can be terminal if terminate is defined' do
    state = Mua::State.new

    state.terminate << true

    expect(state).to be_terminal
  end

  context 'parses input arguments' do
    class ContextWithBranch <  Mua::State::Context
      attr_accessor :branch
    end

    it 'based on simple string input' do
      state = Mua::State.new

      state.parser = -> (_context, input) do
        input.to_s.upcase
      end

      state.interpret << [
        'PRIMARY',
        -> (context) do
          context.branch = :primary
        end
      ]

      state.interpret << [
        'SECONDARY',
        -> (context) do
          context.branch = :secondary
          context.terminated!
        end
      ]

      context = ContextWithBranch.new

      events = state.call(context, :primary).to_a

      expect(events).to match_array([
        [ context, state, :enter ],
        [ context, state, :leave ]
      ])

      expect(context).to_not be_terminated

      context = ContextWithBranch.new

      events = state.call(context, :secondary).to_a

      expect(events).to match_array([
        [ context, state, :enter ],
        [ context, state, :leave ],
        [ context, state, :terminate ]
      ])

      expect(context).to be_terminated
    end
  end

  context 'properly emits events' do
    it 'for a null state definition' do
      state = Mua::State.new

      context = Mua::State::Context.new

      events = state.call(context).to_a

      expect(events).to match_array([
        [ context, state, :enter ],
        [ context, state, :leave ]
      ])
    end

    it 'for a minimal state definition that terminates' do
      state = Mua::State.new
      state.terminate << true

      context = Mua::State::Context.new

      events = state.call(context).to_a

      expect(events).to match_array([
        [ context, state, :enter ],
        [ context, state, :leave ],
        [ context, state, :terminate ]
      ])
    end
  end

  context 'supports nested states' do
    class TrackingContext < Mua::State::Context
      attr_accessor :visited

      def initialize(task: nil, state: nil)
        super(task: task, state: state)

        @visited = [ ]
      end
    end

    it 'hands off correctly to an inner State' do
      parent = Mua::State.new
      parent.terminate << true

      parent.enter << -> (context) {
        context.visited << :parent
      }

      substate = Mua::State.new
      substate.default = -> (context) {
        context.visited << :substate
      }

      parent.interpret << [ :substate, substate ]

      context = TrackingContext.new

      events = StateEventsHelper.reduce(
        parent.call(context, :substate),
        context: context,
        parent: parent,
        substate: substate
      )

      expect(context.visited).to contain_exactly(:parent, :substate)

      expect(events).to match_array([
        [ :context, :parent, :enter ],
        [ :context, :substate, :enter ],
        [ :context, :substate, :leave ],
        [ :context, :parent, :leave ],
        [ :context, :parent, :terminate ]
      ])
    end
  end
end
