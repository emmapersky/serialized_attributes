
require 'test/unit'
require 'rubygems'
require 'activerecord'

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


class SimpleTest < Test::Unit::TestCase
  
  
  def schema!
    DocumentsSchema.suppress_messages{ DocumentsSchema.migrate(:up) }
  end
  
  def test_simple
    schema!
    
    post = Post.create(:title => "First Post", :body => "Lorem ...")
    assert !post.new_record?
    post.comments = [Comment.create(:body => "this is a comment")]
    post.comments << Comment.create(:body => "this is second comment")
    assert_equal Comment.all.map(&:id), post.comment_ids
    post.save
    assert post.reload.comments.length == 2
    
  end
  
end

