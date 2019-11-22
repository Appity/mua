require_relative '../support/mock_stream'

module SimulateExchange
  def simulate_exchange(interpreter, exchange)
    MockStream.line_exchange(interpreter) do |interpreter, context, io|
      exchange.each do |send, recv|
        io.puts(send)

        expect(io.gets).to eq(recv)
      end
    end
  end
end
