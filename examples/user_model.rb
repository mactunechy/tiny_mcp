# Example of a Rails model using the expose_mcp macro
# This would be in app/models/user.rb in a Rails app

class User < ApplicationRecord
  # Expose this model to TinyMCP for read-only operations
  # This creates a tool called 'user_query' that can be used to query the User model
  expose_mcp :read_only, 
             limit: 50, # Maximum number of records to return
             only: [:id, :name, :email], # Only include these fields
             skip_large_fields: true # Skip large text/binary fields
  
  # ... rest of your model ...
  has_many :posts
  has_many :comments
  
  # With this configuration, sensitive attributes like password_digest
  # will not be included in TinyMCP responses even if they exist in the model
  
  # The model will be available via TinyMCP with these operations:
  # - find: Find a user by ID
  # - find_by: Find a user by attributes
  # - where: Find users matching conditions
  # - first: Get the first user
  # - last: Get the last user
  # - count: Count users matching criteria
end

