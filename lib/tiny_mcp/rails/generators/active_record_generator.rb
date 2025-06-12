# frozen_string_literal: true

module TinyMCP
  module Rails
    module Generators
      # Generator for exposing ActiveRecord models to TinyMCP
      class ActiveRecordGenerator < ::Rails::Generators::Base
        desc "Expose ActiveRecord models to TinyMCP for read-only operations"
        
        argument :models, type: :array, default: [], desc: "Models to expose (leave empty to expose all)"
        
        class_option :only, type: :array, default: [], desc: "Fields to include (comma-separated)"
        class_option :except, type: :array, default: [], desc: "Fields to exclude (comma-separated)"
        class_option :limit, type: :numeric, default: 100, desc: "Maximum number of records to return"
        class_option :skip_large_fields, type: :boolean, default: true, desc: "Skip text and binary fields"
        
        def generate_exposure
          if models.empty?
            # Get all models if none specified
            ::Rails.application.eager_load!
            model_classes = ActiveRecord::Base.descendants.reject { |c| c.abstract_class? }
            expose_models(model_classes)
          else
            # Get specified models
            model_classes = models.map { |name| name.classify.constantize rescue nil }.compact
            if model_classes.empty?
              say "No valid models found", :red
              return
            end
            expose_models(model_classes)
          end
        end
        
        private
        
        def expose_models(model_classes)
          model_classes.each do |model_class|
            expose_model(model_class)
          end
          
          # Create initializer to create tools for exposed models
          create_initializer if model_classes.any?
        end
        
        def expose_model(model_class)
          say "Exposing model: #{model_class.name}", :green
          
          # Add expose_mcp to the model
          inject_into_file model_path(model_class), after: "class #{model_class.name} < ApplicationRecord\n" do
            options_str = build_options_string
            "  # Expose this model to TinyMCP for read-only operations\n  expose_mcp :read_only#{options_str}\n\n"
          end
        rescue => e
          say "Error exposing #{model_class.name}: #{e.message}", :red
        end
        
        def model_path(model_class)
          ::Rails.application.root.join('app', 'models', "#{model_class.name.underscore}.rb")
        end
        
        def build_options_string
          options_parts = []
          
          # Add limit
          options_parts << "limit: #{options[:limit]}" if options[:limit] != 100
          
          # Add only fields
          if options[:only].any?
            fields = options[:only].map { |f| ":#{f}" }.join(', ')
            options_parts << "only: [#{fields}]"
          end
          
          # Add except fields
          if options[:except].any?
            fields = options[:except].map { |f| ":#{f}" }.join(', ')
            options_parts << "except: [#{fields}]"
          end
          
          # Add skip_large_fields
          options_parts << "skip_large_fields: false" unless options[:skip_large_fields]
          
          options_parts.any? ? ", #{options_parts.join(', ')}" : ""
        end
      
        def create_initializer
          create_file 'config/initializers/tiny_mcp_models.rb', <<~RUBY
            # frozen_string_literal: true
            
            # Create TinyMCP tools for exposed ActiveRecord models
            ::Rails.application.config.after_initialize do
              # Create the tools when ActiveRecord models are loaded
              model_tools = TinyMCP::Rails::ActiveRecord.create_tools
              
              # Add the tools to TinyMCP's available tools
              # They will be available along with any tools in app/mcp_tools
              TinyMCP::Rails.mcp_tools ||= []
              TinyMCP::Rails.mcp_tools.concat(model_tools)
            end
          RUBY
        end
        
        def create_tool_file(model_class)
          tool_name = "#{model_class.name.underscore}_query"
          file_path = "app/mcp_tools/#{tool_name}.rb"
          
          say "Creating tool file for #{model_class.name}", :green
          
          create_file file_path, <<~RUBY
            # frozen_string_literal: true

            # Tool for querying the #{model_class.name} model
            class #{model_class.name}QueryTool < TinyMCP::Tool
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

