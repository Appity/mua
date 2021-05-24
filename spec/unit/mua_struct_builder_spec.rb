RSpec.describe Mua::Struct::Builder do
  describe 'remap_attrs()' do
    let(:builder) { Mua::State::Context::Builder.new([ ], { }) }

    it 'normalizes list vs. hash arguments' do
      normalized = builder.remap_attrs(
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
      normalized = builder.remap_attrs(
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
end
