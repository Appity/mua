require 'json'

RSpec.describe Mua::Struct, type: :reactor do
  it 'represents a context used to persist information between states and state machines' do
    context = Mua::Struct.new

    expect(context).to be
  end

  it 'can have boolean attributes defined' do
    ExampleContext = Mua::Struct.define(
      example: {
        boolean: true,
        default: false
      }
    )

    context = ExampleContext.new

    expect(context.example?).to be(false)

    context.example = 'yes'

    expect(context.example?).to be(true)
  end

  it 'can have methods defined via a block' do
    defined = Mua::Struct.define do
      def customized?
        true
      end
    end

    context = defined.new

    expect(context).to be_customized
  end

  context 'can quickly define variant contexts using define' do
    context_type = Mua::Struct.define(
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

    it 'can be exported as a Hash' do
      context = context_type.new(
        nil_value: 'not_nil',
        fixed_value: nil,
        with_proc: false,
        with_customization: '-'
      )

      expect(context.to_h).to eq(
        fixed_value: nil,
        nil_value: "not_nil",
        with_customization: "-",
        with_proc: false
      )

      expect(context.as_json).to eq(context.to_h)
    end

    it 'can be exported as JSON' do
      context = context_type.new(
        nil_value: 'not_nil',
        fixed_value: nil,
        with_proc: false,
        with_customization: '-'
      )

      expect(context.to_json).to eq({
        nil_value: 'not_nil',
        fixed_value: nil,
        with_proc: false,
        with_customization: '-'
      }.to_json)
    end
  end
end
