module SerializedAttributes
  def self.included(base)
    return if base.respond_to?(:serialized_attributes_definition)

    base.class_eval do
      class_inheritable_hash :serialized_attributes_definition
      write_inheritable_attribute(:serialized_attributes_definition, {})
      cattr_accessor :serialized_attributes_column
      self.serialized_attributes_column = :serialized_attributes
      
      serialize serialized_attributes_column, Hash
    
      
      base.extend ClassMethods
      include InstanceMethods
    end
  end

  module ClassMethods
    def serialized_attributes_definition
      read_inheritable_attribute(:serialized_attributes_definition)
    end
    
    def instantiate(record)
      object = super(record)
      object.unpack_serialized_attributes!
      object
    end

    def accessible_attribute(name, type, opts = {})
      attribute(name, type, opts.merge({:attr_accessible => true}))
    end

    def serialized_attribute_names
      serialized_attributes_definition.keys
    end    

    def attribute(name, type, opts = {})
      name = name.to_s
      type = SerializedAttributes.type_to_sqltype(type)
      serialized_attributes_definition[name] = ActiveRecord::ConnectionAdapters::Column.new(name.to_s, opts[:default], type.to_s, nil)

      define_method("#{name.to_s}=".to_sym) { |value| @attributes[name] = value }
      define_method(name) { self.class.serialized_attributes_definition[name].type_cast(@attributes[name]) }
      
      attr_accessible name if opts[:attr_accessible]
    end
  end
  
  module InstanceMethods
    def create_or_update
      pack_serialized_attributes!
      super
    end
    
    def serialized_attribute_names
      self.class.serialized_attribute_names
    end

    def unpack_serialized_attributes!
      if @attributes.has_key?(serialized_attributes_column.to_s) && attributes = (self[serialized_attributes_column] || {})
        serialized_attributes_definition.each do |key, column|
          loaded_value = attributes.has_key?(key) ? attributes[key] : column.default
          @attributes[key] = attributes.has_key?(key) ? attributes[key] : column.default
        end
        attributes.slice!(*serialized_attributes_definition.keys)
      end
    end
    
    def pack_serialized_attributes!
      if @attributes.has_key?(serialized_attributes_column.to_s)
        attributes = self[serialized_attributes_column] ||= {}
        serialized_attributes_definition.each do |key, column|
          attributes[key] = self.send key
        end 
      end
      attributes.slice!(*serialized_attributes_definition.keys)
    end
  end

  def to_variable(sym)
    "@#{sym.to_s}".to_sym
  end
  
  def self.type_to_sqltype(type)
    return type if type.is_a?(Symbol) 
    {
      String => :string, Boolean => :boolean,
      Fixnum => :integer, Integer => :integer, BigDecimal => :decimal, Float => :float,
      Date => :date, Time => :time, DateTime => :time
    }[type] || type
  end
  
  module Boolean
  end

end
