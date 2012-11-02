require 'chef'
require 'chef/client'
require 'chef/cookbook_loader'
require 'chefspec/matchers/shared'

# ChefSpec allows you to write rspec examples for Chef recipes to gain faster feedback without the need to converge a
# node.
module ChefSpec

  # The main entry point for running recipes within RSpec.
  class ChefRunner

    @resources = []

    attr_accessor :resources
    attr_reader :step_into
    attr_reader :run_context
    attr_reader :node

    # Instantiate a new runner to run examples with.
    #
    # @param [Hash] options The options for the new runner
    # @option options [String] :cookbook_path The path to the chef cookbook(s) to be tested.
    # @option options [Symbol] :log_level The log level to use (default is :warn)
    # @yield [node] Configuration block for Chef::Node
    def initialize(options={})
      defaults = {:cookbook_path => default_cookbook_path, :log_level => :warn, :dry_run => false, :step_into => []}
      options = {:cookbook_path => options} unless options.respond_to?(:to_hash) # backwards-compatibility
      options = defaults.merge(options)

      the_runner = self
      @resources = []
      @step_into = options[:step_into]
      @do_dry_run = options[:dry_run]

      Chef::Resource.class_eval do
        alias :old_run_action :run_action unless method_defined?(:old_run_action)

        if self.class.methods.include?(:class_variable_set)
          self.class_variable_set :@@runner, the_runner
        else
          @@runner = the_runner
        end

        def run_action(*args)
          action = args.first
          runner = if self.class.methods.include?(:class_variable_get)
            self.class.class_variable_get(:@@runner)
          else
            @@runner
          end

          if runner.step_into.include?(self.resource_name.to_s)
            # Ignore not_if / only_if guards
            if self.only_if.is_a?(Array) # 0.10.x
              self.instance_eval { @not_if = []; @only_if = [] }
            else # 0.9.x
              self.only_if { true }
              self.not_if { false }
            end
            self.old_run_action(action)
          end

          Chef::Log.info("Processing #{self} action #{action} (#{defined_at})") if self.respond_to? :defined_at
          runner.resources << self
        end
      end

      Chef::Config[:solo] = true
      Chef::Config[:cache_type] = "Memory"
      Chef::Cookbook::FileVendor.on_create { |manifest| Chef::Cookbook::FileSystemFileVendor.new(manifest) }
      Chef::Config[:cookbook_path] = options[:cookbook_path]
      Chef::Config[:client_key] = nil
      Chef::Log.verbose = true if Chef::Log.respond_to?(:verbose)
      Chef::Log.level(options[:log_level])
      @client = Chef::Client.new
      fake_ohai(@client.ohai)
      @client.load_node if @client.respond_to?(:load_node) # chef >= 10.14.0
      @node = @client.build_node
      if block_given?
        yield @node
      end
    end

    # Run the specified recipes, but without actually converging the node.
    #
    # @param [array] recipe_names The names of the recipes to execute
    # @return ChefSpec::ChefRunner The runner itself
    def converge(*recipe_names)
      @node.run_list.reset!
      recipe_names.each do |recipe_name|
        @node.run_list << recipe_name
      end
      return self if @do_dry_run

      @client.instance_eval do
        if defined?(@expanded_run_list_with_versions) # 0.10.x
          @run_list_expansion = @node.expand!('disk')
          @expanded_run_list_with_versions = @run_list_expansion.recipes.with_version_constraints_strings
        end
      end

      @resources = []
      if @client.respond_to?(:setup_run_context) # 0.10.x
        @run_context = @client.setup_run_context
      else
        @run_context = Chef::RunContext.new(@client.node, Chef::CookbookCollection.new(Chef::CookbookLoader.new)) # 0.9.x
      end
      runner = Chef::Runner.new(@run_context)
      runner.converge
      self
    end

    %w(directory cookbook_file file template link cron env user execute package service log route ruby_block git subversion group mount ohai ifconfig deploy http_request script powershell remote_directory remote_file).each do |type|
      # Find a resource entry declared with the given name
      #
      # @param  [String] name of a resource
      # @return [Chef::Resource] The matching resource, or Nil
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{type}(name)                           # def cron(name)
          find_resource('#{type}', name)            #   find_resource('cron', name)
        end                                         # end
      RUBY
    end

    # This runner as a string.
    #
    # @return [String] Currently includes the run_list. Format of the string may change between versions of this gem.
    def to_s
      return "chef_run: #{@node.run_list.to_s}" unless @node.run_list.empty?
      'chef_run'
    end

    private

    # Populate basic OHAI attributes required to get recipes working. This is a minimal set - if your recipe example
    # does conditional execution based on these values or additional attributes you can set these via
    # node.automatic_attrs.
    #
    # @param [Ohai::System] ohai The ohai instance to set fake attributes on
    def fake_ohai(ohai)
      {:os => 'chefspec', :os_version => ChefSpec::VERSION, :fqdn => 'chefspec.local', :domain => 'local',
       :ipaddress => '127.0.0.1', :hostname => 'chefspec', :languages => Mash.new({"ruby" => "/usr/somewhere"}),
       :kernel => Mash.new({:machine => 'i386'})}.each_pair do |attribute,value|
         ohai[attribute] = value
       end
    end

    # Infer the default cookbook path from the location of the calling spec.
    #
    # @return [String] The path to the cookbooks directory
    def default_cookbook_path
      Pathname.new(File.join(caller(2).first.split(':').slice(0..-3).join(':'), '..', '..', '..')).cleanpath.to_s
    end

    # Find the resource with the declared type and name
    #
    # @param [String] type The type of resource - e.g. 'file' or 'directory'
    # @param [String] name The resource name
    # @return [Chef::Resource] The matching resource, or Nil
    def find_resource(type, name)
      resources.find{|resource| resource_type(resource) == type and resource.name == name}
    end

  end

end
