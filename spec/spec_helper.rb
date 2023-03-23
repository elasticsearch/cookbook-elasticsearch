require 'rspec/expectations'
require 'chefspec'
require 'chefspec/berkshelf'
require 'chef/application'
require 'json'

Dir['./test/unit/spec/support/**/*.rb'].sort.each { |f| require f }

# use node.default or node.set to put stub data for every node in every test
# could also use this method to stub other node-related things like environment
def node_resources(node)
  # Stub the node and any calls to Environment.Load to return this environment
  env = Chef::Environment.new
  env.name 'chefspec' # matches ./test/integration/
  allow(node).to receive(:chef_environment).and_return(env.name)
  allow(Chef::Environment).to receive(:load).and_return(env)
end

# Stub one guard from the test fixture cookbook to prevent rspec from failing
def stub_resources
  stub_command('/usr/share/elasticsearch/bin/x-pack/users list | grep -q testuser').and_return(0)
end

def stub_chef_zero(platform, version, server)
  Dir['./test/fixtures/nodes/*.json'].sort.each do |f|
    node_data = JSON.parse(IO.read(f), symbolize_names: false)
    node_name = node_data['name']
    server.create_node(node_name, node_data)
    platform.to_s # pacify rubocop
    version.to_s # pacify rubocop
  end

  Dir['./test/fixtures/environments/*.json'].sort.each do |f|
    env_data = JSON.parse(IO.read(f), symbolize_names: false)
    env_name = env_data['name']
    server.create_environment(env_name, env_data)
  end
end

def supported_platforms
  {
    'ubuntu' => ['18.04', '20.04'],
    'centos' => ['7.8.2003', '8'],
  }
end
