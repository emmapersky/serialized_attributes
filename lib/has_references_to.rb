module ActiveRecord
  module Associations
    class HasReferencesToAssociation < HasManyAssociation
      
      def ids
        (@owner["#{@reflection.name.to_s.singularize}_ids"] ||= []).map(&:to_i)
      end
      
      def ids=(array = [])
        @owner["#{@reflection.name.to_s.singularize}_ids"] = array.map(&:to_i)
      end
      
      def construct_sql
        @finder_sql = "#{@reflection.quoted_table_name}.id in (#{ids * ', '})"
        @finder_sql << " AND (#{conditions})" if conditions
        @counter_sql = @finder_sql
      end
      
      def insert_record(record, force = false, validate = true)
        #set_belongs_to_association_for(record)
        force ? record.save! : record.save(validate)
        ids << record.id
      end
      
      def delete_records(records)
        self.ids = ids - records.map(&:id)
      end

      
    end
  
    module ClassMethods
      def create_has_references_to_reflection(association_id, options, &extension)
        #options.assert_valid_keys(valid_keys_for_has_many_association)
        options[:extend] = create_extension_modules(association_id, extension, options[:extend])
        reflection = ActiveRecord::Reflection::AssociationReflection.new(:has_many, association_id, options, self)
        write_inheritable_hash :reflections, name => reflection
        reflection
      end
  
  
      def has_references_to(association_id, options = {}, &extension)
        reflection = create_has_references_to_reflection(association_id, options, &extension)
        #configure_dependency_for_has_many(reflection)
        #add_association_callbacks(reflection.name, reflection.options)

        collection_accessor_methods(reflection, HasReferencesToAssociation)
      end

    
    end
    
    
  end

end
