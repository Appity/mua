RSpec.describe Mua::State::Machine do
  it 'has a default state map' do
    machine = Mua::State::Machine.new

    expect(machine.states).to eq([ :initialize, :finished ])
    expect(machine.state_defined?(:initialize)).to be(true)
    expect(machine.state_defined?(:finished)).to be(true)
    expect(machine.state_defined?(:invalid)).to be(false)

    context = Mua::State::Context.new(state: :initialize)

    events = StateEventsHelper.reduce(
      machine.call(context),
      machine: machine,
      context: context
    )

    expect(events).to match_array([
      [ :context, :machine, :enter ],
      [ :context, :machine, :transition, :finished ],
      [ :context, :machine, :leave ],
      [ :context, :machine, :terminate ]
    ])
  end

  context 'can be defined' do
    it 'yields a proxy as a block argument' do
      machine = Mua::State::Machine.define do |m|
        expect(m).to be_kind_of(Mua::State::Proxy)
      end
    end

    it 'yields in the proxy context with no block argument' do
      # Capture self since this rebinds the block and pushes that out of scope
      test = self

      machine = Mua::State::Machine.define do
        test.expect(self).to test.be_kind_of(Mua::State::Proxy)
      end
    end

    it 'runs the block precisely once when using an argument' do
      count = 0

      machine = Mua::State::Machine.define do |m|
        count += 1
      end

      expect(count).to eq(1)
    end

    it 'runs the block precisely once when ommiting the argument' do
      count = 0

      machine = Mua::State::Machine.define do
        count += 1
      end

      expect(count).to eq(1)
    end

    it 'with long state maps' do
      count = 1000
      entered = [ ]

      machine = Mua::State::Machine.define do
        count.times do |i|
          state(i) do
            enter do |context|
              entered << i
              context.transition!(state: i + 1)
            end
          end
        end

        state(count + 1) do
          enter do |context|
            context.transition!(state: :finished)
          end
        end
      end

      expect(machine.states.length).to eq(count + 3)

      events = machine.run!

      expect(entered).to match_array((0...count).to_a)
    end
  end

  it 'with the parent able to switch between sub-machines' do
    class VisitTrackingContext < Mua::State::Context
      attr_reader :visited
      def initialize(state: nil)
        super

        @visited = [ ]
      end
    end

    states = { }

    machine = Mua::State::Machine.define do
      terminate

      state(:initialize) do
        enter do
          transition!(state: :a)
        end
      end

      states[:a] = state(:a) do
        enter do
          visited << 'A'
          transition!(state: :b)
        end
      end

      states[:b] = state(:b) do
        enter do
          visited << 'B'
          transition!(state: :finished)
        end
      end
    end

    expect(machine.states).to contain_exactly(:initialize, :a, :b, :finished)

    expect(states.keys).to contain_exactly(:a, :b)

    context = VisitTrackingContext.new(state: :initialize)

    events = StateEventsHelper.reduce(
      machine.call(context),
      context: context,
      machine: machine,
      initialize: machine.state[:initialize],
      state_a: states[:a],
      state_b: states[:b]
    )

    expect(events).to match_array([
      [ :context, :machine, :enter ],
      [ :context, :initialize, :enter ],
      [ :context, :initialize, :leave ],
      [ :context, :state_a, :enter ],
      [ :context, :state_a, :leave ],
      [ :context, :state_b, :enter ],
      [ :context, :state_b, :leave ],
      [ :context, :machine, :leave ],
      [ :context, :machine, :terminate ]
    ])
  end
end
