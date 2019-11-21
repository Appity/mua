require_relative '../support/mock_stream'

RSpec.describe Mua::Parser do
  context 'read_stream()' do
    it 'can emit a reader for exact lengths that works independently' do
      parser = Mua::Parser.read_stream(exactly: 10)

      context = MockStream.context('random-content')

      expect(parser.call(context)).to eq('random-con')
      expect(context.input).to_not be_eof
    end

    it 'can emit a reader for exact length that wraps a block' do
      parser = Mua::Parser.read_stream(exactly: 10) do |_context, input|
        input.upcase
      end

      context = MockStream.context('random-content')

      expect(parser.call(context)).to eq('RANDOM-CON')
      expect(context.input).to_not be_eof
    end

    it 'can emit a reader for matches' do
      parser = Mua::Parser.read_stream(match: "\0", chomp: false)

      context = MockStream.context("random\0content\0")

      expect(parser.call(context)).to eq("random\0")
      expect(parser.call(context)).to eq("content\0")
      expect(parser.call(context)).to eq(nil)
      expect(context.input).to be_eof
    end

    it 'can emit a reader for matches that chomps by default' do
      parser = Mua::Parser.read_stream(match: "\0")

      context = MockStream.context("random\0content\0")

      expect(parser.call(context)).to eq('random')
      expect(parser.call(context)).to eq('content')
      expect(parser.call(context)).to eq(nil)
      expect(context.input).to be_eof
    end

    it 'can emit a reader for matches that takes a block' do
      parser = Mua::Parser.read_stream(match: "\0") do |_context, input|
        input&.chomp&.upcase
      end

      context = MockStream.context("random\0content\0")

      expect(parser.call(context)).to eq('RANDOM')
      expect(parser.call(context)).to eq('CONTENT')
      expect(parser.call(context)).to eq(nil)
      expect(context.input).to be_eof
    end

    it 'can emit a reader for lines without chomping' do
      parser = Mua::Parser.read_stream(line: true, chomp: false)

      context = MockStream.context("random\ncontent\n")

      expect(parser.call(context)).to eq("random\n")
      expect(parser.call(context)).to eq("content\n")
      expect(parser.call(context)).to eq(nil)
      expect(context.input).to be_eof
    end

    it 'can emit a reader for lines that chomps by default' do
      parser = Mua::Parser.read_stream(line: true)

      context = MockStream.context("random\ncontent\n")

      expect(parser.call(context)).to eq('random')
      expect(parser.call(context)).to eq('content')
      expect(parser.call(context)).to eq(nil)
      expect(context.input).to be_eof
    end

    it 'can emit a reader for lines that takes a block' do
      parser = Mua::Parser.read_stream(line: true) do |_context, input|
        input&.chomp&.upcase
      end

      context = MockStream.context("random\ncontent\n")

      expect(parser.call(context)).to eq('RANDOM')
      expect(parser.call(context)).to eq('CONTENT')
      expect(parser.call(context)).to eq(nil)
      expect(context.input).to be_eof
    end
  end
end
