RSpec.describe Mua::State::Context::Builder do
  describe 'remap_attrs()' do
    it 'normalizes list vs. hash arguments' do
      normalized = Mua::State::Context::Builder.remap_attrs(
        [ :example ],
        {
          property: { default: true, boolean: true },
          secondary: { default: 2, variable: :@second }
        }
      )

      expect(normalized).to eq(
        example: { variable: :@example, default: nil },
        property: { variable: :@property, default: true, boolean: true },
        secondary: { variable: :@second, default: 2 }
      )
    end

    it 'can take a block argument' do
      normalized = Mua::State::Context::Builder.remap_attrs(
        [ :example ],
        {
          property: { default: true }
        }
      ) do |attr_name, attr_value|
        attr_value[:original] = attr_name

        [ :"#{attr_name}_x", attr_value ]
      end

      expect(normalized).to eq(
        example_x: { variable: :@example, default: nil, original: :example },
        property_x: { variable: :@property, default: true, original: :property },
      )
    end
  end

  context 'class_with_attributes()' do
    context_type = Mua::State::Context::Builder.class_with_attributes(
      [ ],
      initial_state: :custom_state,
      boolean_value: {
        boolean: true,
        default: false
      }
    )

    it 'overrides initial_state' do
      context = context_type.new

      expect(context.initial_state).to eq(:custom_state)
      expect(context.state).to eq(:custom_state)
    end

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

    it 'can include a module in the generated class' do
      inclusion = Module.new do
        def demo
          :demo
        end
      end

      built = Mua::State::Context::Builder.class_with_attributes(
        [ ],
        includes: inclusion
      )

      expect(built).to be_kind_of(Class)
      expect(built.ancestors).to include(inclusion)

      instance = built.new

      expect(instance).to respond_to(:demo)
    end

    it 'can include multiple modules in the generated class' do
      inclusions = [
        Module.new do
          def a
            :a
          end
        end,
        Module.new do
          def b
            :b
          end
        end
      ] 

      built = Mua::State::Context::Builder.class_with_attributes(
        [ ],
        includes: inclusions
      )

      expect(built).to be_kind_of(Class)
      expect(built.ancestors).to include(*inclusions)

      instance = built.new

      expect(instance).to respond_to(:a, :b)
    end
  end
end
