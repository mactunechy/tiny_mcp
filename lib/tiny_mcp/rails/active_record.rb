# frozen_string_literal: true

module TinyMCP
  module Rails
    # ActiveRecord integration for TinyMCP
    # Provides a simple DSL for exposing models to TinyMCP with read-only operations
    module ActiveRecord
      extend ActiveSupport::Concern

      class_methods do
        # Expose this model to TinyMCP for read-only operations
        # @param mode [Symbol] The exposure mode (:read_only, :full - future expansion)
        # @param options [Hash] Options for configuring the exposure
        # @option options [Integer] :limit Maximum number of records to return (default: 100)
        # @option options [Array<Symbol>] :only Fields to include (default: all)
        # @option options [Array<Symbol>] :except Fields to exclude
        # @option options [Boolean] :skip_large_fields Skip fields that might contain large data
        def expose_mcp(mode = :read_only, **options)
          # Only support read_only mode for now
          raise ArgumentError, "Only :read_only mode is supported" unless mode == :read_only
          
          # Set default options
          options = {
            limit: 100,
            only: nil,
            except: nil,
            skip_large_fields: true
          }.merge(options)
          
          # Store options
          class_attribute :tiny_mcp_exposure, instance_writer: false
          self.tiny_mcp_exposure = {
            mode: mode,
            options: options
          }
          
          # Register this model as exposed
          TinyMCP::Rails::ActiveRecord.register_exposed_model(self)
        end
      end
      
      # Registry for exposed models
      @exposed_models = []
      
      class << self
        attr_reader :exposed_models
        
        # Register a model as exposed to TinyMCP
        def register_exposed_model(model_class)
          @exposed_models << model_class unless @exposed_models.include?(model_class)
        end
        
        # Create TinyMCP tools for all exposed models
        def create_tools
          @exposed_models.map do |model_class|
            create_tool_for_model(model_class)
          end
        end
        
        # Create a TinyMCP tool for a specific model
        def create_tool_for_model(model_class)
          # Create a new tool class dynamically
          tool_class = Class.new(TinyMCP::Tool) do
            name "#{model_class.name.underscore}_query"
            desc "Query the #{model_class.name} model with read-only operations"
            
            # Add tool arguments based on the model's primary key
            arg :operation, :string, "Operation to perform (find, find_by, where, first, last, count)"
            opt :params, :string, "Parameters for the operation in JSON format"
            opt :limit, :integer, "Maximum number of records to return"
            opt :fields, :string, "Comma-separated list of fields to include"
            
            define_method :call do |operation:, params: nil, limit: nil, fields: nil|
              # Process the operation
              case operation.to_sym
              when :find
                handle_find(model_class, params, limit, fields)
              when :find_by
                handle_find_by(model_class, params, fields)
              when :where
                handle_where(model_class, params, limit, fields)
              when :first
                handle_first(model_class, fields)
              when :last
                handle_last(model_class, fields)
              when :count
                handle_count(model_class, params)
              else
                "Error: Unsupported operation '#{operation}'"
              end
            end
            
            # Helper methods for each operation
            define_method :handle_find do |model_class, params, limit, fields|
              return "Error: 'params' is required for find operation" if params.blank?
              
              begin
                id = JSON.parse(params)
                record = model_class.find(id)
                format_record(record, fields)
              rescue => e
                "Error: #{e.message}"
              end
            end
            
            define_method :handle_find_by do |model_class, params, fields|
              return "Error: 'params' is required for find_by operation" if params.blank?
              
              begin
                conditions = JSON.parse(params)
                record = model_class.find_by(conditions)
                record ? format_record(record, fields) : "No #{model_class.name} found matching criteria"
              rescue => e
                "Error: #{e.message}"
              end
            end
            
            define_method :handle_where do |model_class, params, limit, fields|
              return "Error: 'params' is required for where operation" if params.blank?
              
              begin
                conditions = JSON.parse(params)
                records = model_class.where(conditions)
                
                # Apply limit
                max_limit = model_class.tiny_mcp_exposure[:options][:limit]
                custom_limit = limit.present? ? [limit.to_i, max_limit].min : max_limit
                records = records.limit(custom_limit)
                
                format_collection(records, fields)
              rescue => e
                "Error: #{e.message}"
              end
            end
            
            define_method :handle_first do |model_class, fields|
              record = model_class.first
              record ? format_record(record, fields) : "No #{model_class.name} records found"
            end
            
            define_method :handle_last do |model_class, fields|
              record = model_class.last
              record ? format_record(record, fields) : "No #{model_class.name} records found"
            end
            
            define_method :handle_count do |model_class, params|
              if params.present?
                begin
                  conditions = JSON.parse(params)
                  count = model_class.where(conditions).count
                  "Found #{count} #{model_class.name.pluralize} matching criteria"
                rescue => e
                  "Error: #{e.message}"
                end
              else
                count = model_class.count
                "Total #{model_class.name.pluralize}: #{count}"
              end
            end
            
            # Helper methods for formatting output
            define_method :format_record do |record, fields|
              options = {}
              
              # Apply field filtering
              if fields.present?
                options[:only] = fields.split(',').map(&:strip).map(&:to_sym)
              else
                exposure_options = record.class.tiny_mcp_exposure[:options]
                options[:only] = exposure_options[:only] if exposure_options[:only].present?
                options[:except] = exposure_options[:except] if exposure_options[:except].present?
                
                # Skip large fields if configured
                if exposure_options[:skip_large_fields]
                  large_field_types = [:text, :binary, :json, :jsonb]
                  large_fields = record.class.columns.select { |c| large_field_types.include?(c.type) }.map(&:name).map(&:to_sym)
                  options[:except] ||= []
                  options[:except] += large_fields
                end
              end
              
              # Format the record as JSON
              result = record.as_json(options)
              JSON.pretty_generate(result)
            end
            
            define_method :format_collection do |records, fields|
              if records.any?
                formatted = records.map { |record| format_record(record, fields) }
                "Found #{records.size} #{model_class.name.pluralize}:\n#{formatted.join("\n")}"
              else
                "No #{model_class.name.pluralize} found matching criteria"
              end
            end
          end
          
          # Return the dynamically created tool class
          tool_class
        end
      end
    end
  end
end

# Add the extension to ActiveRecord::Base if Rails and ActiveRecord are defined
if defined?(ActiveRecord)
  ActiveRecord::Base.include TinyMCP::Rails::ActiveRecord
end

