RSpec.describe Mua::State::Machine do
  it 'has a default state map' do
    Async do |task|
      machine = Mua::State::Machine.new(task: task)

      expect(machine.states).to match_array(%i[ ])
    end
  end

  it 'can have deep state maps' do
    state_machine = Class.new(Mua::State::Machine)
    count = 5000

    count.times do |i|
      state_machine.send(:state, :"iteration#{i}") do
        enter do
          transition!(:"iteration#{i+1}")
        end
      end
    end

    state_machine.send(:state, :"iteration#{count}") do
      enter do
        transition!(:terminated)
      end
    end

    expect(state_machine.states.length).to eq(count + 2)
  end

  it 'does something' do
  end
end
