require_relative '../support/mock_stream'

RSpec.describe Mua::Parser do
  context 'read_stream' do
    it 'can emit a reader for exact lengths that works independently' do
      parser = Mua::Parser.read_stream(exactly: 10)

      context = MockStream.context('random-content')

      expect(parser.call(context)).to eq('random-con')
    end

    it 'can emit a reader for exact length that wraps a block' do
      parser = Mua::Parser.read_stream(exactly: 10) do |_context, input|
        input.upcase
      end

      context = MockStream.context('random-content')

      expect(parser.call(context)).to eq('RANDOM-CON')
    end

    it 'can emit a reader for matches that works independently' do
      parser = Mua::Parser.read_stream(match: "\n")

      context = MockStream.context("random\ncontent\n")

      expect(parser.call(context)).to eq("random\n")
      expect(parser.call(context)).to eq("content\n")
      expect(parser.call(context)).to eq(nil)
    end

    it 'can emit a reader for matches that works independently and chomps' do
      parser = Mua::Parser.read_stream(match: "\n", chomp: true)

      context = MockStream.context("random\ncontent\n")

      expect(parser.call(context)).to eq('random')
      expect(parser.call(context)).to eq('content')
      expect(parser.call(context)).to eq(nil)
    end

    it 'can emit a reader for matches that takes a block' do
      parser = Mua::Parser.read_stream(match: "\n") do |_context, input|
        input&.chomp&.upcase
      end

      context = MockStream.context("random\ncontent\n")

      expect(parser.call(context)).to eq('RANDOM')
      expect(parser.call(context)).to eq('CONTENT')
      expect(parser.call(context)).to eq(nil)
    end
  end
end
