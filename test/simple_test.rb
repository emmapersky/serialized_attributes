require 'test/unit'
require 'rubygems'
require 'active_record'
require 'logger'

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => ':memory:'

require File.dirname(__FILE__) + "/../lib/serialized_attributes"  # load plugin

class DocumentsSchema < ActiveRecord::Migration
  def self.up
    create_table :documents do |t|
      t.text :serialized_attributes     # <---  here all your dynamic fields will be saved
      t.string :type
      t.integer :reference_id           # <---  you can also define any sql columns for your indexes
      t.timestamps
    end
    
    create_table :widgets do |t|
      t.string :name
      t.boolean :active
      t.text :serialized_attributes
      t.timestamps
    end
  end
end

class Document < ActiveRecord::Base
  include SerializedAttributes
end

class Post < Document
  attribute :title, String
  attribute :body,  String
  attribute :is_published, Boolean, :default => false

  attribute :comment_ids, Array     # <--- serialized Array of ids of associated comments
  has_references_to :comments

  validates_presence_of :title, :body

end

class Comment < Document
  attribute :body, String
  attribute :post_id, Integer
  belongs_to :post

  validates_presence_of :body

end

class ModelBefore < ActiveRecord::Base
  set_table_name :documents
end

class ModelAfter < ActiveRecord::Base
  set_table_name :documents
  include SerializedAttributes
  attribute :custom_field, String, :default => 'default value'
end

class ModelSecond < ActiveRecord::Base
  set_table_name :documents
  include SerializedAttributes
  attribute :custom_field_renamed, String, :default => 'new default value'
end

class Widget < ActiveRecord::Base
  include SerializedAttributes
  
  #white list the name attribute, others may not be mass assigned
  attr_accessible :name, String
end

class Sprocket < Widget
  #we want the attribute in_motion, but it may not be mass assigned
  attribute :in_motion, Boolean
  
  #we want to allow the size attribute to be mass assigned
  accessible_attribute :size, Integer
end


class SimpleTest < Test::Unit::TestCase
  #ActiveRecord::Base.logger = Logger.new(STDOUT)
  DocumentsSchema.suppress_messages{ DocumentsSchema.migrate(:up) }

  def test_simple
    post = Post.create(:title => "First Post", :body => "Lorem ...")
    assert !post.new_record?
    post.comments << Comment.new(:body => "this is a comment")
    post.comments << Comment.create(:body => "this is second comment")
    post.comments.create(:body => "one more")
        
    assert_equal Comment.all.map(&:id), post.comment_ids
    post.save
    
    assert_equal 3, post.reload.comments.size
  end
  
  
  # => it should initialize attributes on objects even if they were serialized before that attribute existed
  def test_null_serialized_attributes_column_on_already_exists_records
    # => to test this, we create a model (ModelBefore) that has no attributes (but has an attributes column)
    # => then we create second model (ModelAfter) which we force to use the same table as ModelBefore (set_table_name)
    # => We create an object using ModelBefore and then try to load it using ModelAfter.
    model_before = ModelBefore.create
    model_after = ModelAfter.find(model_before.id)
  
    assert_equal model_after.custom_field, 'default value'
  end
  
  # => it should not unpack custom attributes on objects if they have been removed
  def test_removed_custom_field
    # => to test this, we use a similar method to the prior test, but change (or remove) an attribute
    model1 = ModelAfter.create
    model2 = ModelSecond.find(model1.id)
    model2.save!
    model2.reload
    
    assert_equal model2.serialized_attributes.keys.include?('custom_field'), false
  end
  
  # => it should create attributes as whitelisted and allow their mass assignment
  def test_accessible_attributes_are_created
    sprocket = Sprocket.create(:name => "Spacely's Space Sprocket", :size => 99)
    assert sprocket.size == 99
  end
  
  # => test that the names of the serialized attributes are correctly returned by a class
  def test_serizalied_attribute_names_are_returned_by_the_class
    assert Sprocket.serialized_attribute_names.sort == ['in_motion', 'size'].sort
  end
  
  # => test that the names of the serialized attributes are correctly returned by the instance
  def test_serizalied_attribute_names_are_returned_by_an_instance
    assert Sprocket.new.serialized_attribute_names.sort == ['in_motion', 'size'].sort
  end  

  # => test that default value is proprely used in just created model
  def test_default_value_in_just_create_model
    assert_equal 'new default value', ModelSecond.new.custom_field_renamed
  end

  # => test that default value is proprely used in saved model
  def test_default_value_in_save_model
    model =  ModelSecond.create
    model.reload
    assert_equal 'new default value', model.custom_field_renamed
  end
end
