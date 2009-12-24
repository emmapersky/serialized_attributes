
module SerializedAttributes
  def self.included(base)
    return if base.respond_to?(:serialized_attributes_definition)

    base.class_eval do
      class_inheritable_hash :serialized_attributes_definition
      
      cattr_accessor :serialized_attributes_column
      self.serialized_attributes_column = :serialized_attributes
      
      serialize serialized_attributes_column, Hash
    
      class << self
        include ClassMethods
        alias_method_chain :columns, :serialized_attributes
        alias_method_chain :instantiate, :serialized_attributes
      end 
      
      include InstanceMethods
      alias_method_chain :attributes_with_quotes, :exclude_serialized_attributes
      alias_method_chain :create_or_update, :serialized_attributes
    end
  end
  
  module ClassMethods
    def columns_with_serialized_attributes
      columns_without_serialized_attributes + (serialized_attributes_definition.try(:values) || [])
    end
    
    def instantiate_with_serialized_attributes(record)
      object = instantiate_without_serialized_attributes(record)
      object.unpack_serialized_attributes!
      object
    end
    
    def attribute(name, type, opts = {})
      type = SerializedAttributes.type_to_sqltype(type)
      if type.is_a?(Symbol)
        self.serialized_attributes_definition = {name.to_s => ActiveRecord::ConnectionAdapters::Column.new(name.to_s, opts[:default], type.to_s, nil)}
      elsif type.is_a?(Class)
        self.serialized_attributes_definition = {name.to_s => ActiveRecord::ConnectionAdapters::Column.new(name.to_s, opts[:default], :text, nil)}
        serialize name.to_sym, type
      else
        fail ArgumentError, "Unknown type #{type}"
      end
      validates_presence_of name if opts[:requied] == true
    end
    
  end
  
  module InstanceMethods
    def attributes_with_quotes_with_exclude_serialized_attributes(*args)
      attributes_with_quotes_without_exclude_serialized_attributes(*args).except(*serialized_attributes_definition.keys)
    end

    def create_or_update_with_serialized_attributes
      pack_serialized_attributes!
      create_or_update_without_serialized_attributes
    end
    
    def unpack_serialized_attributes!
      if @attributes.has_key?(serialized_attributes_column.to_s) && attributes = self[serialized_attributes_column]
        serialized_attributes_definition.each do |key, column|
          @attributes[key] = attributes.has_key?(key) ? attributes[key] : column.default
        end 
      end
    end
    
    def pack_serialized_attributes!
      if @attributes.has_key?(serialized_attributes_column.to_s)
        #self[serialized_attributes_storage] ||= {}
        #self[serialized_attributes_storage].merge! attributes.slice(*serialized_attributes_definition.keys)
        attributes = self[serialized_attributes_column] ||= {}
        serialized_attributes_definition.each do |key, column|
          attributes[key] = self.send key
        end 
      end
    end
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


ActiveRecord::Base.class_eval do
  def self.define_serialized_attributes  
    include SerializedAttributes unless self.include?(SerializedAttributes)
    proxy = Class.new(BlankSlate){
        def initialize(delegate)
          @delegate = delagate
        end
        def column(name, type, opts = {})
          @delegate.attribute name, type, opts
        end
        def method_missing(type, name, opts = {})
          @delegate.attribute name, type, opts
        end
      }.new(self)
    yield proxy
  end

end