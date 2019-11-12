module ExpectMappingHelper
  def expect_mapping(map, &proc)
    expect(map.map do |input, output|
      [ input, proc[input] ]
    end.to_h).to eq(map)
  end
end
