require_relative '../support/mock_stream'

RSpec.describe Mua::State::Machine do
  it 'has a default state map' do
    machine = Mua::State::Machine.new.prepare

    expect(machine.states).to eq([ :initialize, :finished ])
    expect(machine.state_defined?(:initialize)).to be(true)
    expect(machine.state_defined?(:finished)).to be(true)
    expect(machine.state_defined?(:invalid)).to be(false)

    context = Mua::State::Context.new(state: :initialize)

    events = StateEventsHelper.map_locals do
      machine.run!(context)
    end

    expect(events).to eq([
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

    it 'runs the block precisely once when omitting the argument' do
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
        state(:initialize) do
          enter do |context|
            context.transition!(state: 0)
          end
        end

        count.times do |i|
          state(i) do
            enter do |context|
              entered << i
              context.transition!(state: i + 1)
            end
          end
        end

        state(count) do
          enter do |context|
            context.transition!(state: :finished)
          end
        end
      end

      expect(machine.states).to eq([ :initialize, *(0..count).to_a, :finished ])

      events = machine.run!(Mua::State::Context.new)

      expect(entered).to eq((0...count).to_a)
    end

    it 'with a custom initial state' do
      entered = false

      machine = Mua::State::Machine.define(
        initial_state: :custom,
        final_state: :done
      ) do
        state(:custom) do
          enter do |context|
            entered = true
            context.transition!(state: :done)
          end
        end
      end

      expect(machine.states).to eq([ :custom, :done ])

      context = Mua::State::Context.new(state: :custom)

      events = machine.run!(context)

      expect(entered).to be(true)
    end

    it 'with a reference to an undefined state, which will error out' do
      machine = Mua::State::Machine.define do
        state(:initialize) do
          enter do |context|
            context.transition!(state: :invalid)
          end
        end
      end

      context = Mua::State::Context.new

      expect { machine.run!(context) }.to raise_exception(Mua::State::Machine::InvalidStateError)
    end
  end

  it 'with the parent able to switch between sub-machines' do
    VisitTrackingContext = Mua::State::Context.define(visited: -> { [ ] })

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

  it 'has states which inherit the parser of the parent machine' do
    machine = Mua::State::Machine.define(name: 'inherited_parser') do
      parser(match: "\n", chomp: true)

      state(:first) do
        default do |context, line|
          context.lines << [ :first, line ]

          context.transition!(state: :second)
        end
      end

      state(:second) do
        default do |context, line|
          context.lines << [ :second, line ]

          context.transition!(state: :third)
        end
      end

      state(:third) do
        default do |context, line|
          context.lines << [ :third, line ]

          context.transition!(state: :fourth)
        end
      end

      state(:fourth) do
        default do |context, line|
          context.lines << [ :fourth, line ]

          context.terminated!
        end
      end
    end

    context = Mua::State::Context.define(
      initial_state: :first,
      lines: -> { [ ] }
    ).new(
      input: MockStream.new("this\nhas\nlines\n")
    )

    expect(machine.name).to eq('inherited_parser')
    machine.run!(context)

    expect(context.lines).to eq([
      [ :first, 'this' ],
      [ :second, 'has' ],
      [ :third, 'lines' ]
    ])
  end
end
