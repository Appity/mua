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

  def local_object_ids(bb)
    bb.local_variables.map do |v|
      case (var = bb.local_variable_get(v))
      when nil, true, false, Numeric
        # Ignore values that are common singletons
      else
        [ bb.local_variable_get(v).object_id, v ]
      end
    end.compact.to_h
  end

  def map_locals(&block)
    aliases = local_object_ids(block.binding)
    array = [ ]

    yield(
      -> (*event) do
        array << event.map do |e|
          aliases[e.object_id] || e
        end
      end
    )

    array
  end

  def events_with_binding(events, b)
    aliases = local_object_ids(block.binding)

    events.map do |event|
      case (event)
      when Array
        event.map do |e|
          e.nil? ? e : (aliases[e] || e)
        end
      else
        event.nil? ? event : (aliases[event] || event)
      end
    end
  end

  extend self
end
