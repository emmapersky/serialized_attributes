serialized_attributes
=====================

This is a very cool lib, allows to define dynamic serialized fields in your AR model, which acts as normal rails db columns.
It give you full power of rails to your virtual columns: validations, rails forms, error messages, type casting
(integer, date/time), type safety, :dirty? s, etc.. STI is supported! Basic associations is working too!

Example of usage
----------------

### STI table def

    create_table :documents do |t|
      t.string :type
      t.text :serialized_attributes     # <---  here all your dynamic fields will be saved
      t.integer :reference_id           # <---  you can also define any sql columns for your indexes
      t.timestamps
    end

### STI base model

    class Document < ActiveRecord::Base
      include SerializedAttributes
    end

### Other models..

    class Post < Document
      attribute :title, String
      attribute :body,  String
      attribute :is_published, Boolean, :default => false
      
      attribute :comment_ids, Array             # <--- serialized Array of ids of associated comments
      has_references_to :comments
      
      validates_presence_of :title, :body
    end
    
    class Comment < Document
      attribute :body, String, :requied => true # <--- validates_presence_of :body
      attribute :post_id, Integer
      belongs_to :post
    end
    
IRB fun
-------

    post = Post.create(:title => "First Post", :body => "Lorem ...")
    assert !post.new_record?
    post.comments = [Comment.create(:body => "this is a comment")]
    post.comments << Comment.create(:body => "this is second comment")
    assert_equal Comment.all.map(&:id), post.comment_ids
    post.save
    assert post.reload.comments.length == 2

# Mass Assignment and Protect Attributes
	class Widget < ActiveRecord::Base
	  include SerializedAttributes
	
	  #protect other attributes from mass assignment
	  attr_accessible :name

		#specifically permit a given serialized attribute to be mass assigned
	  accessible_attribute :creator, String
	end


# limitations
- has-references-to association dont update reverse association
- serialized-attributes column saved every time you call :save without depending on what is actually changed