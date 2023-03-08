unified_mode true

include ElasticsearchCookbook::Helpers

property :plugin_name,
         String,
         name_property: true
property :url,
         String
property :chef_proxy,
         [true, false],
         default: false
property :options,
         String,
         default: ''

# this is what helps the various resources find each other
property :instance_name,
        String

action :install do
  return if plugin_exists(new_resource.plugin_name)

  # since install can take a URL argument instead
  url_or_name = new_resource.url || new_resource.plugin_name
  manage_plugin("install #{url_or_name}")
end

action :remove do
  return unless plugin_exists(new_resource.plugin_name)

  manage_plugin("remove #{new_resource.plugin_name}")
end

action_class do
  def manage_plugin(arguments)
    es_user = find_es_resource(Chef.run_context, :elasticsearch_user, new_resource)
    es_install = find_es_resource(Chef.run_context, :elasticsearch_install, new_resource)
    es_conf = find_es_resource(Chef.run_context, :elasticsearch_configure, new_resource)

    config_name = new_resource.instance_name || es_conf.instance_name || 'elasticsearch'

    assert_state_is_valid(es_user, es_install, es_conf) unless whyrun_mode?

    # shell_out! automatically raises on error, logs command output
    # required for package installs that show up with parent dir owned by root
    plugin_dir_exists = ::File.exist?(es_conf.path_plugins)

    unless plugin_dir_exists
      cmd_str = "mkdir -p #{es_conf.path_plugins}"
      if whyrun_mode?
        Chef::Log.info("Would run command: #{cmd_str}")
      else
        shell_out_as_user!(cmd_str, es_install.type, config_name)
        # new_resource.updated_by_last_action(true)
      end
    end

    unless plugin_exists(new_resource.plugin_name)
      cmd_str = "#{es_conf.path_bin}/elasticsearch-plugin #{arguments.chomp(' ')} #{new_resource.options}".chomp(' ')

      # if whyrun_mode?
      #   Chef::Log.info("Would run command: #{cmd_str}")
      # else
      command_array = cmd_str.split(' ')
      shell_out_as_user!(command_array, es_install.type, config_name)
      # new_resource.updated_by_last_action(true)
      # end
    end
  end

  def plugin_exists(name)
    es_conf = find_es_resource(Chef.run_context, :elasticsearch_configure, new_resource)
    path = es_conf.path_plugins

    Dir.entries(path).any? do |plugin|
      next if plugin =~ /^\./
      name == plugin
    end
  rescue
    false
  end

  def assert_state_is_valid(_es_user, _es_install, es_conf)
    unless es_conf.path_plugins # we do not check existence (may not exist if no plugins installed)
      raise "Could not determine the plugin directory (#{es_conf.path_plugins}). Please check elasticsearch_configure[#{es_conf.name}]."
    end

    unless es_conf.path_bin && ::File.exist?(es_conf.path_bin)
      raise "Could not determine the binary directory (#{es_conf.path_bin}). Please check elasticsearch_configure[#{es_conf.name}]."
    end

    true
  end

  # def shell_out_as_user!(command, run_ctx)
  def shell_out_as_user!(_command, _install_type, config_name = nil)
    # we need to figure out the env file path to set environment for plugins
    # include_file_resource = find_resource!(:template, "elasticsearch.in.sh-#{config_name}")
    # env = { 'ES_INCLUDE' => include_file_resource.path }

    # Add HTTP Proxy vars unless explicitly told not to
    # if new_resource.chef_proxy
    #   env['ES_JAVA_OPTS'] = "#{ENV['ES_JAVA_OPTS']} #{get_java_proxy_arguments}"
    # end

    # See this link for an explanation:
    # https://www.elastic.co/guide/en/elasticsearch/plugins/2.1/plugin-management.html
    # if install_type == 'package' || install_type == 'repository'
    #   # package installations should install plugins as root
    # shell_out!(command, env: env, timeout: 1200)
    # else
    # non-package installations should install plugins as the ES user
    # es_user = find_resource!(:elasticsearch_user, new_resource)
    # shell_out!(command, user: es_user.username, group: es_user.groupname, env: env, timeout: 1200)
    # end
  end
end
