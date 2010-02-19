module ActiveCMIS
  class PropertyDefinition
    attr_reader :object_type, :id, :local_name, :local_namespace, :query_name,
      :display_name, :description, :property_type, :repeating, :updatability,
      :inherited, :required, :queryable, :orderable, :choices, :open_choice,
      :default_value

    def initialize(object_type, property_definition)
      @object_type = object_type
      @property_definition = property_definition
      params = {}
      property_type = nil
      property_definition.map do |node|
        next unless node.namespace.href == NS::CMIS_CORE

        # FIXME: add support for "choices"
        case node.node_name
        when "id"
          @id = node.text
        when "localName"
          @local_name = node.text
        when "localNamespace"
          @local_namespace = node.text
        when "displayName"
          @display_name = node.text
        when "queryName"
          @query_name = node.text
        when "propertyType"
          # Will be post processed, but we need to know all the parameters before we can pick an atomic type
          property_type = node.text
        when "cardinality"
          @cardinality = node.text
        when "updatability"
          @updatability = node.text
        when "inherited"
          @inherited = AtomicType::Boolean.xml_to_bool(node.text)
        when "required"
          @required = AtomicType::Boolean.xml_to_bool(node.text)
        when "queryable"
          @queryable = AtomicType::Boolean.xml_to_bool(node.text)
        when "orderable"
          @orderable = AtomicType::Boolean.xml_to_bool(node.text)
        when "openChoice"
          @open_choice = AtomicType::Boolean.xml_to_bool(node.text)
        when "maxValue", "minValue", "resolution", "precision", "maxLength"
          params[node.node_name] = node.text
        end
      end

      @property_type = case property_type.downcase
      when "string"
        AtomicType::String.new(params["maxLength"].to_i)
      when "decimal"
        AtomicType::Decimal.new(params["resolution"].to_i, params["minValue"].to_f, params["maxValue"].to_f)
      when "integer"
        AtomicType::Integer.new(params["minValue"].to_i, params["maxValue"].to_i)
      when "datetime"
        AtomicType::DateTime.new(params["resolution"] || ($stderr.puts "Warning: no resolution for DateTime"; "time") )
      when "html"
        AtomicType::HTML.new
      when "id"
        AtomicType::ID.new
      when "boolean"
        AtomicType::Boolean.new
      when "uri"
        AtomicType::URI.new
      else
        raise "Unknown property type #{property_type}"
      end
    end

    def inspect
      "#{object_type.display_name}:#{id} => #{property_type}#{"[]" if repeating}"
    end
    alias to_s inspect

    def property_name
      "property#{property_type}"
    end

    def extract_property(properties)
      elements = properties.children.select do |n|
        n.node_name == property_name &&
          n["propertyDefinitionId"] == id &&
          n.namespace.href == NS::CMIS_CORE
      end
      if elements.empty?
        if required
          raise ActiveCMIS::Error.new("The server behaved strange: attribute #{self.inspect} required but not present among properties")
        end
        nil
      elsif elements.length == 1
        values = elements.first.children
        if required && values.empty?
          raise ActiveCMIS::Error.new("The server behaved strange: attribute #{self.inspect} required but no values specified")
        end
        if !repeating && values.length > 1
          raise ActiveCMIS::Error.new("The server behaved strange: attribute #{self.inspect} not repeating but multiple values given")
        end
        values
      else
        raise "Property is not unique"
      end
    end
  end
end