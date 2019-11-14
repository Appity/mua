module StateEventsHelper
  def reduce(events, **aliases)
    aliases = aliases.invert

    events.map do |event|
      case (event)
      when Array
        event.map do |e|
          aliases[e] || e
        end
      else
        event
      end
    end
  end

  extend self
end
