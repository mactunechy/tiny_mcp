# frozen_string_literal: true

module TinyMCP
  module Rails
    # Module for handling read-only operations on Rails models
    # This module provides a DSL for annotating Rails models to ensure
    # they are only used for read operations, avoiding memory-intensive
    # queries that could slow down the server or be expensive for AI token usage
    module ReadOnly
      extend ActiveSupport::Concern

      class_methods do
        # Defines read-only options for this model in the context of TinyMCP
        # @param options [Hash] Options for controlling read-only behavior
        # @option options [Integer] :limit Maximum number of records to return (default: 100)
        # @option options [Array<Symbol>] :only Whitelist of attributes to include
        # @option options [Array<Symbol>] :except Blacklist of attributes to exclude
        # @option options [Boolean] :skip_associations Skip loading associations (default: true)
        # @option options [Array<Symbol>] :allowed_associations Whitelist of associations to load
        # @option options [Hash] :default_scope Default scope to apply to all queries
        def tiny_mcp_read_only(options = {})
          options = {
            limit: 100,
            skip_associations: true,
            only: nil,
            except: nil,
            allowed_associations: [],
            default_scope: {}
          }.merge(options)

          # Store options in class variable
          cattr_accessor :tiny_mcp_options
          self.tiny_mcp_options = options

          # Add helper methods for TinyMCP
          extend TinyMCP::Rails::ReadOnly::ClassMethods
          include TinyMCP::Rails::ReadOnly::InstanceMethods
        end
      end

      # Helper methods added to model class
      module ClassMethods
        # Safe finder that respects read-only constraints
        # @param args [Array] Arguments to pass to where
        # @param options [Hash] Additional options
        # @return [ActiveRecord::Relation] Limited relation
        def tiny_mcp_find(*args, **options)
          relation = tiny_mcp_scope
          
          if args.any?
            relation = relation.where(*args)
          end
          
          if options.any?
            relation = relation.where(options)
          end
          
          # Always apply limit to prevent memory issues
          relation.limit(tiny_mcp_options[:limit])
        end

        # Returns a safely limited scope for this model
        # @return [ActiveRecord::Relation] Limited relation
        def tiny_mcp_scope
          scope = self.all
          
          # Apply default scope if specified
          if tiny_mcp_options[:default_scope].present?
            scope = scope.where(tiny_mcp_options[:default_scope])
          end
          
          # Apply scope for select
          if tiny_mcp_options[:only].present?
            scope = scope.select(tiny_mcp_options[:only])
          elsif tiny_mcp_options[:except].present? && tiny_mcp_options[:except].any?
            # Select all columns except the excluded ones
            columns = self.column_names.map(&:to_sym) - tiny_mcp_options[:except]
            scope = scope.select(columns)
          end
          
          scope
        end

        # Returns a representation of the model for AI tool usage
        # @return [Hash] Model metadata for documentation
        def tiny_mcp_schema
          {
            model_name: name,
            table_name: table_name,
            attributes: attribute_names,
            read_only_config: tiny_mcp_options,
            sample_query: "#{name}.tiny_mcp_find(id: 1)"
          }
        end
      end

      # Helper methods added to model instances
      module InstanceMethods
        # Safe version of as_json that respects read-only constraints
        # @param options [Hash] Options to pass to as_json
        # @return [Hash] JSON representation
        def tiny_mcp_as_json(options = {})
          opt = self.class.tiny_mcp_options
          
          # Start with default options
          json_options = {}
          
          # Apply only/except filters
          if opt[:only].present?
            json_options[:only] = opt[:only]
          elsif opt[:except].present?
            json_options[:except] = opt[:except]
          end
          
          # Handle associations
          if opt[:skip_associations]
            # Skip all associations by default
            json_options[:include] = {}
          elsif opt[:allowed_associations].any?
            # Only include allowed associations
            json_options[:include] = opt[:allowed_associations].index_with { |_| {} }
          end
          
          # Merge with provided options
          json_options.merge!(options)
          
          # Call original as_json with our options
          as_json(json_options)
        end
      end
    end
  end
end

# Add the read-only extension to ActiveRecord::Base if Rails is defined
if defined?(ActiveRecord)
  ActiveRecord::Base.include TinyMCP::Rails::ReadOnly
end

