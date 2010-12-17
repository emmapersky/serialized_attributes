require 'test/unit'
require 'rubygems'
require 'active_record'

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => ':memory:'

require File.dirname(__FILE__) + "/../init"  # load plugin

class DocumentsSchema < ActiveRecord::Migration
  def self.up
    create_table :documents do |t|
      t.text :serialized_attributes     # <---  here all your dynamic fields will be saved
      t.string :type
      t.integer :reference_id           # <---  you can also define any sql columns for your indexes
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


class SimpleTest < Test::Unit::TestCase
  # ActiveRecord::Base.logger = Logger.new(STDOUT)
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

  def test_null_serialized_attributes_column_on_already_exists_records
    model_before = ModelBefore.create
    model_after = ModelAfter.find(model_before.id)

    assert_equal model_after.custom_field, 'default value'
  end

  def test_removed_custom_field
    model1 = ModelAfter.create
    model2 = ModelSecond.find(model1.id)
    model2.save!
    model2.reload
    assert_equal model2.serialized_attributes.keys.include?('custom_field'), false
  end
end
