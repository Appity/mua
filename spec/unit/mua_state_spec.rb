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

  it 'can be assigned a parent' do
    parent = Mua::State.new
    child = Mua::State.new(parent: parent)

    expect(child.parent).to be(parent)
  end

  it 'can produce an interpreter block with branches and default' do
    state = Mua::State.new

    state.interpret << [ 'example', -> (context) { 'example.caught' } ]
    state.default = -> (context, branch) { '%s.out' % branch }

    interpreter = state.interpreter

    context = Mua::State::Context.new

    expect(interpreter.call(context, 'example')).to eq('example.caught')
    expect(interpreter.call(context, 'invalid')).to eq('invalid.out')
  end

  it 'can produce an interpreter block no branches but a default' do
    state = Mua::State.new

    state.default = -> (context, branch) { '%s.out' % branch }

    interpreter = state.interpreter

    context = Mua::State::Context.new

    expect(interpreter.call(context, 'example')).to eq('example.out')
    expect(interpreter.call(context, 'invalid')).to eq('invalid.out')
  end

  it 'can produce an interpreter block with no definitions' do
    state = Mua::State.new

    interpreter = state.interpreter

    context = Mua::State::Context.new

    expect(interpreter.call(context, nil)).to be(nil)
  end

  it 'will capture regular expression matches' do
    state = Mua::State.new

    state.interpret << [
      /([a-z]+)(\d+)/,
      -> (context, _match, word, num) { [ word, num.to_i ] }
    ]
    
    interpreter = state.interpreter

    context = Mua::State::Context.new

    expect(interpreter.call(context, 'test1')).to contain_exactly('test', 1)
    expect(interpreter.call(context, 'catch22')).to contain_exactly('catch', 22)
    expect(interpreter.call(context, 'busted')).to be(nil)
  end

  it 'can have handlers populated manually', focus: true do
    state = Mua::State.new
    ran = [ ]

    state.parser = -> (context) {
      ran << :parser

      context.input.shift&.to_s
    }
    state.enter << -> (context) { ran << :enter }
    state.leave << -> (context) { ran << :leave }
    state.interpret << [ 'example', -> (context) { ran << :example } ]
    state.default = -> (context, branch) { ran << :default }
    state.terminate << -> (context) { ran << :terminate }

    context = Mua::State::Context.new(input: [ :example ])
    state.run!(context)

    expect(ran).to contain_exactly(:enter, :parser, :example, :leave, :terminate)

    ran.clear
    context.input = [ :not_example ]
    state.run!(context)

    expect(ran).to contain_exactly(:enter, :parser, :default, :leave, :terminate)
  end

  it 'can be terminal if terminate is defined' do
    state = Mua::State.new

    state.terminate << true

    expect(state).to be_terminal
  end

  context 'parses input arguments' do
    ContextWithBranch =  Mua::State::Context.define(:branch)

    it 'based on simple string input' do
      state = Mua::State.new

      state.parser = -> (context) do
        context.read&.to_s&.upcase
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

      context = ContextWithBranch.new(input: [ :primary ])

      events = StateEventsHelper.map_locals do
        state.run!(context)
      end

      expect(context.branch).to eq(:primary)
      expect(context).to_not be_terminated

      expect(events).to match_array([
        [ :context, :state, :enter ],
        [ :context, :state, :leave ]
      ])

      context = ContextWithBranch.new(input: [ :secondary ])

      events = StateEventsHelper.map_locals do
        state.run!(context)
      end

      expect(context.branch).to eq(:secondary)
      expect(context).to be_terminated

      expect(events).to match_array([
        [ :context, :state, :enter ],
        [ :context, :state, :leave ],
        [ :context, :state, :terminate ]
      ])
    end
  end

  context 'properly emits events' do
    it 'for a null state definition' do
      state = Mua::State.new

      context = Mua::State::Context.new

      events = StateEventsHelper.map_locals do
        state.run!(context)
      end

      expect(events).to match_array([
        [ :context, :state, :enter ],
        [ :context, :state, :leave ],
        [ :context, :state, :terminate ]
      ])
    end

    it 'for a minimal state definition that terminates' do
      state = Mua::State.new
      state.terminate << true

      context = Mua::State::Context.new

      events = StateEventsHelper.map_locals do
        state.run!(context)
      end

      expect(events).to match_array([
        [ :context, :state, :enter ],
        [ :context, :state, :leave ],
        [ :context, :state, :terminate ]
      ])
    end
  end

  context 'supports nested states' do
    TrackingContext = Mua::State::Context.define(visited: -> { [ ] })

    it 'hands off correctly to an inner State' do
      parent = Mua::State.new
      parent.terminate << true

      parent.enter << -> (context) {
        context.visited << :parent
      }

      substate = Mua::State.new
      substate.enter << -> (context) {
        context.visited << :substate
      }
      substate.interpret << [
        :branch,
        -> (context) {
          context.visited << :branch
        }
      ]

      parent.interpret << [ :substate, substate ]

      context = TrackingContext.new(input: [ :substate, :branch ])

      events = StateEventsHelper.map_locals do
        parent.run!(context)
      end

      expect(context.visited).to eq([ :parent, :substate, :branch ])

      expect(events).to match_array([
        [ :context, :parent, :enter ],
        [ :context, :substate, :enter ],
        [ :context, :substate, :leave ],
        [ :context, :parent, :leave ],
        [ :context, :parent, :terminate ]
      ])
    end
  end

  it 'can be used to parse out simple inputs' do
    state = Mua::State.define do
      preprocess do |context|
        context.input = context.input.downcase.split(/\s*\b/).map do |v|
          case (v)
          when /\A\d+\z/
            v.to_i
          else
            v
          end
        end
      end

      parser do |context|
        context.input.shift
      end

      interpret(/[!\.\?]/) do |context, match|
        context.parts << { punctuation: match }

        context.transition!(state: :finished)
      end

      interpret(/(\w+)/) do |context, _match, word|
        context.parts << { word: word }
      end

      interpret(0..9999) do |context, number|
        context.parts << { number: number }
      end

      default do |context|
        context.parts << { fail: true }

        context.transition!(state: :finished)
      end
    end

    context = Mua::State::Context.define(
      parts: -> () { [ ] }
    ).new

    context.input = 'You cannot cut back on RFC 5322!'

    events = state.run!(context)

    expect(context.parts).to match_array([
      { word: 'you' },
      { word: 'cannot' },
      { word: 'cut' },
      { word: 'back' },
      { word: 'on' },
      { word: 'rfc' },
      { number: 5322 },
      { punctuation: '!' }
    ])
  end
end
