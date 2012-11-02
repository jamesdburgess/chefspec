Given /^a Chef cookbook with a recipe that declares a file resource( and sets the contents)?$/ do |sets_contents|
  file_contents = sets_contents.nil? ? '' : 'content "hello world!"'
  steps %Q{
    Given a file named "cookbooks/example/recipes/default.rb" with:
    """ruby
      file "hello-world.txt" do
        content "hello world"
        action :create
        #{file_contents}
      end
    """
  }
end

Given /^a Chef cookbook with a recipe that deletes a file/ do
  steps %q{
    Given a file named "cookbooks/example/recipes/default.rb" with:
    """ruby
      file "hello-world.txt" do
        content "hello world"
        action :delete
      end
    """
      And a file named "hello-world.txt" with:
      """
      Hello world!
      """
  }
end

Given /^a Chef cookbook with a recipe that creates a directory$/ do
  steps %q{
    Given a file named "cookbooks/example/recipes/default.rb" with:
    """ruby
      directory "foo" do
        action :create
      end
    """
  }
end

Given /^a Chef cookbook with a recipe that deletes a directory$/ do
  steps %q{
    Given a file named "cookbooks/example/recipes/default.rb" with:
    """
      directory "foo" do
        action :delete
      end
    """
    And a directory named "foo"
  }
end

Given /^a Chef cookbook with a recipe that creates a remote file$/ do
  steps %q{
    Given a file named "cookbooks/example/recipes/default.rb" with:
    """ruby
      remote_file "hello-world.txt" do
        action :create
      end
    """
  }
end

Given /^a Chef cookbook with a recipe that sets file ownership$/ do
  steps %q{
    Given a file named "cookbooks/example/recipes/default.rb" with:
    """ruby
      file "hello-world.txt" do
        owner "user"
        group "group"
      end
    """
    And a file named "hello-world.txt" with:
    """
    Hello world!
    """
  }
  @original_stat = owner_and_group 'hello-world.txt'
end

Given /^a Chef cookbook with a recipe that sets directory ownership/ do
  steps %q{
    Given a file named "cookbooks/example/recipes/default.rb" with:
    """ruby
      directory "foo" do
        owner "user"
        group "group"
      end
    """
    And a directory named "foo"
  }
  @original_stat = owner_and_group 'foo'
end

Given /^the recipe has a spec example that expects the file to be declared$/ do
  steps %q{
    Given a file named "cookbooks/example/spec/default_spec.rb" with:
    """ruby
      require "chefspec"

      describe "example::default" do
        let(:chef_run) {ChefSpec::ChefRunner.new.converge 'example::default'}
        it "should create hello-world.txt" do
          chef_run.should create_file 'hello-world.txt'
        end
      end
    """
  }
end

Given /^the recipe has a spec example of the(?: cookbook)? file contents$/ do
  steps %q{
    Given a file named "cookbooks/example/spec/default_spec.rb" with:
    """ruby
      require "chefspec"

      describe "example::default" do
        let(:chef_run) {ChefSpec::ChefRunner.new.converge 'example::default'}
        it "should create hello-world.txt" do
          chef_run.should create_file_with_content 'hello-world.txt', 'hello world!'
        end
      end
    """
  }
end

Given /^the recipe has a spec example that expects the file to be deleted$/ do
  steps %q{
    Given a file named "cookbooks/example/spec/default_spec.rb" with:
    """ruby
      require "chefspec"

      describe "example::default" do
        let(:chef_run) {ChefSpec::ChefRunner.new.converge 'example::default'}
        it "should delete hello-world.txt" do
          chef_run.should delete_file 'hello-world.txt'
        end
      end
    """
  }
end

Given /^the recipe has a spec example that expects the directory to be created/ do
  steps %q{
    Given a file named "cookbooks/example/spec/default_spec.rb" with:
    """ruby
      require "chefspec"

      describe "example::default" do
        let(:chef_run) {ChefSpec::ChefRunner.new.converge 'example::default'}
        it "should create the directory" do
          chef_run.should create_directory 'foo'
        end
      end
    """
  }
end

Given /^the recipe has a spec example that expects the directory to be deleted/ do
  steps %q{
    Given a file named "cookbooks/example/spec/default_spec.rb" with:
    """ruby
      require "chefspec"

      describe "example::default" do
        let(:chef_run) {ChefSpec::ChefRunner.new.converge 'example::default'}
        it "should delete the directory" do
          chef_run.should delete_directory 'foo'
        end
      end
    """
  }
end

Given /^the recipe has a spec example that expects the remote file to be created/ do
  steps %q{
    Given a file named "cookbooks/example/spec/default_spec.rb" with:
    """ruby
      require "chefspec"

      describe "example::default" do
        let(:chef_run) {ChefSpec::ChefRunner.new.converge 'example::default'}
        it "should create the remote file" do
          chef_run.should create_remote_file 'hello-world.txt'
        end
      end
    """
  }
end

Given /^the recipe has a spec example that expects the file to be set to be owned by a specific user$/ do
  steps %q{
    Given a file named "cookbooks/example/spec/default_spec.rb" with:
    """ruby
      require "chefspec"

      describe "example::default" do
        let(:chef_run) {ChefSpec::ChefRunner.new.converge 'example::default'}
        it "should set file ownership" do
          chef_run.file('hello-world.txt').should be_owned_by('user', 'group')
        end
      end
    """
  }
end

Given /^the recipe has a spec example that expects the directory to be set to be owned by a specific user$/ do
  steps %q{
    Given a file named "cookbooks/example/spec/default_spec.rb" with:
    """ruby
      require "chefspec"

      describe "example::default" do
        let(:chef_run) {ChefSpec::ChefRunner.new.converge 'example::default'}
        it "should set directory ownership" do
          chef_run.directory('foo').should be_owned_by('user', 'group')
        end
      end
    """
  }
end

Then /^the file will not have been created$/ do
  step %q{the file "hello-world.txt" should not exist}
end

Then /^the file will not have been deleted/ do
  step %q{a file named "hello-world.txt" should exist}
end

Then /^the directory will not have been created$/ do
  step %q{a directory named "foo" should not exist}
end

Then /^the directory will not have been deleted$/ do
  step %q{a directory named "foo" should exist}
end

Then /^the file will not have had its ownership changed$/ do
  @original_stat.should eql(owner_and_group 'hello-world.txt')
end

Then /^the directory will not have had its ownership changed$/ do
  @original_stat.should eql(owner_and_group 'foo')
end
