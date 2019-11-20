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

  def map_locals(&block)
    aliases = block.binding.local_variables.map do |v|
      [ block.binding.local_variable_get(v), v ]
    end.to_h

    block.call.map do |event|
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

  def events_with_binding(events, b)
    aliases = b.local_variables.map do |v|
      [ b.local_variable_get(v), v ]
    end.to_h

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
