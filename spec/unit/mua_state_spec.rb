RSpec.describe Mua::State, type: :reactor, timeout: 5 do
  it 'has minimal defaults' do
    state = Mua::State.new

    expect(state.parser).to be(nil)
    expect(state.enter).to eq([ ])
    expect(state.leave).to eq([ ])
    expect(state.interpret).to eq([ ])
    expect(state.rescue_from).to eq([ ])
    expect(state.default).to be(nil)

    expect(state).to be_prepared
    expect(state.interpret).to be_frozen

    expect(state.interpreter).to be_kind_of(Proc)
    expect(state.dispatcher).to be_kind_of(Proc)
  end

  it 'can be assigned a name' do
    state = Mua::State.new(name: :example)

    expect(state.name).to eq(:example)
  end

  it 'can be assigned a parent' do
    parent = Mua::State.new
    child = Mua::State.new(parent: parent)

    expect(child.parent).to be(parent)
    expect(child.default).to be(parent.interpreter)
  end

  it 'can produce an interpreter block with branches and default' do
    state = Mua::State.new do |s|
      s.interpret << [ 'example', -> (context) { 'example.caught' } ]
      s.default = -> (context, branch) { '%s.out' % branch }
    end

    interpreter = state.interpreter

    context = Mua::State::Context.new

    expect(interpreter.call(context, 'example')).to eq('example.caught')
    expect(interpreter.call(context, 'invalid')).to eq('invalid.out')
  end

  it 'can produce an interpreter block no branches but a default' do
    state = Mua::State.new do |s|
      s.default = -> (context, branch) { '%s.out' % branch }
    end

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
    state = Mua::State.new do |s|
      s.interpret << [
        /([a-z]+)(\d+)/,
        -> (context, _match, word, num) { [ word, num.to_i ] }
      ]
    end
    
    interpreter = state.interpreter

    context = Mua::State::Context.new

    expect(interpreter.call(context, 'test1')).to contain_exactly('test', 1)
    expect(interpreter.call(context, 'catch22')).to contain_exactly('catch', 22)
    expect(interpreter.call(context, 'busted')).to be(nil)
  end

  it 'can have handlers populated manually', focus: true do
    ran = [ ]

    test_exception = Class.new(Mua::Error)

    state = Mua::State.new do |s|
      s.parser = -> (context) {
        ran << :parser

        context.input.shift&.to_s
      }
      
      s.enter << -> (context) { ran << :enter }
      s.leave << -> (context) { ran << :leave }
      s.interpret << [ 'example', -> (context) { ran << :example; raise test_exception } ]
      s.rescue_from << [ test_exception, -> (context, exception) { ran << :exception } ]
      s.default = -> (context, branch) { ran << :default }
    end

    context = Mua::State::Context.new(input: [ :example ])
    state.run(context)

    expect(ran).to eq([ :enter, :parser, :example, :exception, :parser, :leave ])

    ran.clear
    context.input = [ :not_example ]
    state.run(context)

    expect(ran).to eq([ :enter, :parser, :default, :leave ])
  end

  context 'parses input arguments' do
    ContextWithBranch =  Mua::State::Context.define(:branch)

    it 'based on simple string input' do
      state = Mua::State.new do |s|
        s.parser = -> (context) do
          context.input.shift&.to_s&.upcase
        end

        s.interpret << [
          'PRIMARY',
          -> (context) do
            context.branch = :primary
          end
        ]

        s.interpret << [
          'SECONDARY',
          -> (context) do
            context.branch = :secondary
            
            context.terminated!
          end
        ]
      end

      context = ContextWithBranch.new(input: [ :primary ])

      events = StateEventsHelper.map_locals do |fn|
        state.run(context, &fn)
      end

      expect(context.branch).to eq(:primary)

      expect(events).to eq([
        [ :context, :state, :enter ],
        [ :context, :state, :branch, 'PRIMARY' ],
        [ :context, :state, :leave ],
        [ :context, :state, :terminate ]
      ])

      expect(context).to be_terminated

      context = ContextWithBranch.new(input: [ :secondary ])

      events = StateEventsHelper.map_locals do |fn|
        state.run(context, &fn)
      end

      expect(context.branch).to eq(:secondary)
      expect(context).to be_terminated

      expect(events).to match_array([
        [ :context, :state, :enter ],
        [ :context, :state, :branch, 'SECONDARY' ],
        [ :context, :state, :leave ],
        [ :context, :state, :terminate ]
      ])
    end
  end

  context 'properly emits events' do
    it 'for a null state definition' do
      state = Mua::State.new

      context = Mua::State::Context.new

      events = StateEventsHelper.map_locals do |fn|
        state.run(context, &fn)
      end

      expect(events).to eq([
        [ :context, :state, :enter ],
        [ :context, :state, :leave ],
        [ :context, :state, :terminate ]
      ])
    end
  end

  context 'supports nested states' do
    TrackingContext = Mua::State::Context.define(visited: -> { [ ] })

    it 'hands off correctly to an inner State' do
      substate = Mua::State.new do |s|
        s.parser = -> (context) { context.input.shift }
        s.enter << -> (context) {
          context.visited << :substate
        }

        s.interpret << [
          :branch,
          -> (context) {
            context.visited << :branch
          }
        ]
      end

      parent = Mua::State.new do |s|
        s.parser = -> (context) { context.input.shift }
        s.enter << -> (context) {
          context.visited << :parent
        }

        s.interpret << [ :substate, substate ]
      end

      context = TrackingContext.new(input: [ :substate, :branch ])

      events = StateEventsHelper.map_locals do |fn|
        parent.run(context, &fn)
      end

      expect(events).to eq([
        [ :context, :parent, :enter ],
        [ :context, :parent, :branch, :substate ],
        [ :context, :substate, :enter ],
        [ :context, :substate, :branch, :branch ],
        [ :context, :substate, :leave ],
        [ :context, :substate, :terminate ],
        [ :context, :parent, :leave ],
        [ :context, :parent, :terminate ]
      ])

      expect(context.visited).to eq([ :parent, :substate, :branch ])
    end
  end

  it 'allows reflection of interpreter branches' do
    p = -> (context) { }

    state = Mua::State.define do |s|
      s.interpret(:a, &p)
      s.interpret(:b, &p)
    end

    expect(state.interpreter_branches).to eq([
      [ :a, p ],
      [ :b, p ]
    ])
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
      parts: -> { [ ] }
    ).new

    context.input = 'You cannot cut back on RFC 5322!'

    events = state.run(context)

    expect(context.parts).to eq([
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

  it 'can parse with optional redo for continuations' do
    state = Mua::State.define do
      preprocess do |context|
        context.input = context.input.downcase.split(/\s+/)
      end

      parser do |context|
        case (input = context.input.shift)
        when nil
          context.finished!
        when 'a', 'an', 'the'
          context.buffer << input
          context.parser_redo!
        else
          buffer, context.buffer = context.buffer, [ ]
          [ *buffer, input ].join(' ')
        end
      end

      default do |context, word|
        context.parts << word
      end
    end

    context = Mua::State::Context.define(
      buffer: -> { [ ] },
      parts: -> { [ ] }
    ).new

    context.input = 'This is a story about an interpreter'

    events = state.run(context) do |c, s, *ev|
      p(state: s.name, event: ev) if (ENV['DEBUG'])
    end

    expect(context.parts).to eq([
      'this',
      'is',
      'a story',
      'about',
      'an interpreter'
    ])
  end

  it 'can capture exceptions generated in the parser' do
    custom_exception = Class.new(Exception)

    state = Mua::State.define do
      parser do |context|
        raise custom_exception
      end

      rescue_from(custom_exception) do |context, exception|
        context.exception_captured = exception
      end

      leave do |context|
        context.transition!(state: :finished)
      end
    end

    context = Mua::State::Context.define(
      :exception_captured
    ).new

    expect { state.run(context) }.to_not raise_exception(custom_exception)

    expect(context.exception_captured).to be_kind_of(custom_exception)
  end

  context 'define()' do
    it 'can define a state with a name' do
      state = Mua::State.define(name: :example)

      expect(state).to be_kind_of(Mua::State)
      expect(state.name).to eq(:example)
    end
  end
end
