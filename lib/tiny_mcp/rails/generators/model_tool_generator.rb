# frozen_string_literal: true

require 'rails/generators/base'

module TinyMCP
  module Rails
    module Generators
      # Generator to create explicit tool files for exposed ActiveRecord models
      class ModelToolGenerator < ::Rails::Generators::Base
        desc "Create tool files for ActiveRecord models exposed to TinyMCP"
        
        argument :models, type: :array, default: [], desc: "Models to create tools for (leave empty to create for all exposed models)"
        
        def generate_tool_files
          if models.empty?
            # Get all models if none specified
            ::Rails.application.eager_load! if defined?(::Rails)
            if defined?(ActiveRecord::Base)
              model_classes = ::ActiveRecord::Base.descendants.reject { |c| c.abstract_class? }
              model_classes = model_classes.select { |c| c.respond_to?(:tiny_mcp_exposure) && c.tiny_mcp_exposure.present? }
            else
              say "ActiveRecord not found. Make sure you're running in a Rails application.", :red
              return
            end
          else
            # Get specified models
            model_classes = models.map do |name|
              begin
                klass = name.classify.constantize 
                klass.respond_to?(:tiny_mcp_exposure) && klass.tiny_mcp_exposure.present? ? klass : nil
              rescue
                nil
              end
            end.compact
          end
          
          if model_classes.empty?
            say "No exposed models found. Use 'expose_mcp :read_only' in your model first.", :red
            return
          end
          
          # Create a tool file for each model
          model_classes.each do |model_class|
            create_tool_file(model_class)
          end
        end
        
        private
        
        def create_tool_file(model_class)
          tool_name = "#{model_class.name.underscore}_query"
          file_path = "app/mcp_tools/#{tool_name}.rb"
          
          say "Creating tool file for #{model_class.name}", :green
          
          create_file file_path, <<~RUBY
            # frozen_string_literal: true

            # Tool for querying the #{model_class.name} model
            class #{tool_name.camelize} < TinyMCP::Tool
              name '#{tool_name}'
              desc 'Query the #{model_class.name} model with read-only operations'
              
              arg :operation, :string, "Operation to perform (find, find_by, where, first, last, count)"
              opt :params, :string, "Parameters for the operation in JSON format"
              opt :limit, :integer, "Maximum number of records to return"
              opt :fields, :string, "Comma-separated list of fields to include"
              
              def call(operation:, params: nil, limit: nil, fields: nil)
                # Get model configuration
                max_limit = #{model_class.name}.tiny_mcp_exposure[:options][:limit]
                only_fields = #{model_class.name}.tiny_mcp_exposure[:options][:only]
                except_fields = #{model_class.name}.tiny_mcp_exposure[:options][:except]
                skip_large_fields = #{model_class.name}.tiny_mcp_exposure[:options][:skip_large_fields]
                
                # Process operation
                case operation.to_sym
                when :find
                  handle_find(params, limit, fields)
                when :find_by
                  handle_find_by(params, fields)
                when :where
                  handle_where(params, limit, fields)
                when :first
                  handle_first(fields)
                when :last
                  handle_last(fields)
                when :count
                  handle_count(params)
                else
                  "Error: Unsupported operation '\#{operation}'"
                end
              end
              
              private
              
              # Find a record by ID
              def handle_find(params, limit, fields)
                return "Error: 'params' is required for find operation" if params.blank?
                
                begin
                  id = JSON.parse(params)
                  record = #{model_class.name}.find(id)
                  format_record(record, fields)
                rescue => e
                  "Error: \#{e.message}"
                end
              end
              
              # Find a record by attributes
              def handle_find_by(params, fields)
                return "Error: 'params' is required for find_by operation" if params.blank?
                
                begin
                  conditions = JSON.parse(params)
                  record = #{model_class.name}.find_by(conditions)
                  record ? format_record(record, fields) : "No #{model_class.name} found matching criteria"
                rescue => e
                  "Error: \#{e.message}"
                end
              end
              
              # Find records matching conditions
              def handle_where(params, limit, fields)
                return "Error: 'params' is required for where operation" if params.blank?
                
                begin
                  conditions = JSON.parse(params)
                  records = #{model_class.name}.where(conditions)
                  
                  # Apply limit
                  max_limit = #{model_class.name}.tiny_mcp_exposure[:options][:limit]
                  custom_limit = limit.present? ? [limit.to_i, max_limit].min : max_limit
                  records = records.limit(custom_limit)
                  
                  format_collection(records, fields)
                rescue => e
                  "Error: \#{e.message}"
                end
              end
              
              # Get the first record
              def handle_first(fields)
                record = #{model_class.name}.first
                record ? format_record(record, fields) : "No #{model_class.name} records found"
              end
              
              # Get the last record
              def handle_last(fields)
                record = #{model_class.name}.last
                record ? format_record(record, fields) : "No #{model_class.name} records found"
              end
              
              # Count records matching criteria
              def handle_count(params)
                if params.present?
                  begin
                    conditions = JSON.parse(params)
                    count = #{model_class.name}.where(conditions).count
                    "Found \#{count} #{model_class.name.pluralize} matching criteria"
                  rescue => e
                    "Error: \#{e.message}"
                  end
                else
                  count = #{model_class.name}.count
                  "Total #{model_class.name.pluralize}: \#{count}"
                end
              end
              
              # Format a single record
              def format_record(record, fields)
                options = {}
                
                # Apply field filtering
                if fields.present?
                  options[:only] = fields.split(',').map(&:strip).map(&:to_sym)
                else
                  exposure_options = #{model_class.name}.tiny_mcp_exposure[:options]
                  options[:only] = exposure_options[:only] if exposure_options[:only].present?
                  options[:except] = exposure_options[:except] if exposure_options[:except].present?
                  
                  # Skip large fields if configured
                  if exposure_options[:skip_large_fields]
                    large_field_types = [:text, :binary, :json, :jsonb]
                    large_fields = #{model_class.name}.columns.select { |c| large_field_types.include?(c.type) }.map(&:name).map(&:to_sym)
                    options[:except] ||= []
                    options[:except] += large_fields
                  end
                end
                
                # Format the record as JSON
                result = record.as_json(options)
                JSON.pretty_generate(result)
              end
              
              # Format a collection of records
              def format_collection(records, fields)
                if records.any?
                  formatted = records.map { |record| format_record(record, fields) }
                  "Found \#{records.size} #{model_class.name.pluralize}:\\n\#{formatted.join("\\n")}"
                else
                  "No #{model_class.name.pluralize} found matching criteria"
                end
              end
            end
          RUBY
        end
      end
    end
  end
end
