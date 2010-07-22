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
    
    create_table :mixeds do |t|
      t.title
      t.body
      t.text :serialized_attributes     # <---  here all your dynamic fields will be saved
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

class Mixed < ActiveRecord::Base
  set_table_name :mixeds
end

class MixedWithSA < ActiveRecord::Base
  set_table_name :mixeds

  include SerializedAttributes
  attribute :custom_field, String, :default => 'default value'
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
    Mixed.create
    doc = MixedWithSA.first

    assert_equal doc.custom_field, 'default value'
  end
end
