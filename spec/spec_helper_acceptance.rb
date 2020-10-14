if !ENV['BEAKER_PUPPET_COLLECTION'] && !ENV['BEAKER_PUPPET_AGENT_VERSION']
  ENV['BEAKER_PUPPET_COLLECTION'] = 'puppet5'
end

require 'beaker-pe'
require 'beaker-puppet'
require 'beaker-rspec'
require 'beaker/puppet_install_helper'
require 'beaker/module_install_helper'

# Collect global options from the environment.
if ENV['LOGSTASH_VERSION'].nil?
  raise 'Please set the LOGSTASH_VERSION environment variable.'
end
LS_VERSION = ENV['LOGSTASH_VERSION']

IS_PRERELEASE = if LS_VERSION =~ %r{(alpha|beta|rc)}
                  true
                else
                  false
                end

def expect_no_change_from_manifest(manifest)
  expect(apply_manifest(manifest).exit_code).to eq(0)
end

def http_package_url
  url_root = "https://artifacts.elastic.co/downloads/logstash/logstash-#{LS_VERSION}"

  case fact('osfamily')
  when 'Debian'
    "#{url_root}.deb"
  when 'RedHat', 'Suse'
    "#{url_root}.rpm"
  end
end

def local_file_package_url
  "file:///tmp/#{logstash_package_filename}"
end

def puppet_fileserver_package_url
  "puppet:///modules/logstash/#{logstash_package_filename}"
end

def logstash_package_filename
  File.basename(http_package_url)
end

def logstash_package_version
  package_version = if LS_VERSION =~ %r{(alpha|beta|rc)}
                      LS_VERSION.tr('-', '~')
                    else
                      LS_VERSION
                    end

  case fact('osfamily') # FIXME: Put this logic in the module, not the tests.
  when 'RedHat'
    "#{package_version}-1"
  when 'Debian', 'Suse'
    "1:#{package_version}-1"
  end
end

def logstash_config_manifest
  <<-END
  logstash::configfile { 'basic_config':
    content => 'input { tcp { port => 2000 } } output { null {} }'
  }
  END
end

def install_logstash_manifest(extra_args = nil)
  <<-END
  class { 'elastic_stack::repo':
    version    => #{LS_VERSION[0]},
    prerelease => #{IS_PRERELEASE},
  }
  class { 'logstash':
    manage_repo  => true,
    version      => '#{logstash_package_version}',
    #{extra_args if extra_args}
  }

  #{logstash_config_manifest}
  END
end

def include_logstash_manifest
  <<-END
  class { 'elastic_stack::repo':
    version    => #{LS_VERSION[0]},
    prerelease => #{IS_PRERELEASE},
  }

  include logstash

  #{logstash_config_manifest}
  END
end

def install_logstash_from_url_manifest(url, extra_args = nil)
  <<-END
  class { 'logstash':
    package_url  => '#{url}',
    #{extra_args if extra_args}
  }

  #{logstash_config_manifest}
  END
end

def install_logstash_from_local_file_manifest(extra_args = nil)
  install_logstash_from_url_manifest(local_file_package_url, extra_args)
end

def remove_logstash_manifest
  "class { 'logstash': ensure => 'absent' }"
end

def stop_logstash_manifest
  "class { 'logstash': status => 'disabled' }"
end

# Provide a basic Logstash install. Useful as a testing pre-requisite.
def install_logstash(extra_args = nil)
  result = apply_manifest(install_logstash_manifest(extra_args), catch_failures: true)
  sleep 5 # FIXME: This is horrible.
  result
end

def include_logstash
  result = apply_manifest(include_logstash_manifest, catch_failures: true, debug: true)
  sleep 5 # FIXME: This is horrible.
  result
end

def install_logstash_from_url(url, extra_args = nil)
  manifest = install_logstash_from_url_manifest(url, extra_args)
  result = apply_manifest(manifest, catch_failures: true)
  sleep 5 # FIXME: This is horrible.
  result
end

def install_logstash_from_local_file(extra_args = nil)
  install_logstash_from_url(local_file_package_url, extra_args)
end

def remove_logstash
  result = apply_manifest(remove_logstash_manifest)
  sleep 5 # FIXME: This is horrible.
  result
end

def stop_logstash
  result = apply_manifest(stop_logstash_manifest, catch_failures: true)
  shell('ps -eo comm | grep java | xargs kill -9', accept_all_exit_codes: true)
  sleep 5 # FIXME: This is horrible.
  result
end

def logstash_process_list
  ps_cmd = 'ps -ww --no-headers -C java -o user,command | grep logstash'
  shell(ps_cmd, accept_all_exit_codes: true).stdout.split("\n")
end

def logstash_settings
  YAML.safe_load(shell('cat /etc/logstash/logstash.yml').stdout)
end

def expect_setting(setting, value)
  expect(logstash_settings[setting]).to eq(value)
end

def pipelines_from_yaml
  YAML.safe_load(shell('cat /etc/logstash/pipelines.yml').stdout)
end

def service_restart_message
  "Service[logstash]: Triggered 'refresh'"
end

# Install Puppet
run_puppet_install_helper
configure_type_defaults_on(hosts)
install_ca_certs unless ENV['PUPPET_INSTALL_TYPE'] =~ %r{pe}i
install_module_on(hosts)
install_module_dependencies_on(hosts)

hosts.each do |host|
  # Get remote puppet codedir
  codedir = puppet_config(host, 'codedir')

  # Add files directory to hold some test files
  on(host, "mkdir #{codedir}/modules/logstash/files/")

  # Aquire a binary package of Logstash.
  logstash_download = "/tmp/#{logstash_package_filename}"
  `curl -s -o #{logstash_download} #{http_package_url}` unless File.exist?(logstash_download)
  # ...send it to the test host
  scp_to(host, logstash_download, '/tmp/')
  # ...and also make it available as a "puppet://" url, by putting it in the
  # 'files' directory of the Logstash module.
  scp_to(host, logstash_download, "#{codedir}/modules/logstash/files/")

  # ...and put some grok pattern examples in their too.
  Dir.glob('./spec/fixtures/grok-patterns/*').each do |f|
    scp_to(host, f, "#{codedir}/modules/logstash/files/")
  end

  # Provide a Logstash plugin as a local Gem.
  scp_to(host, './spec/fixtures/plugins/logstash-output-cowsay-5.0.0.gem', '/tmp/')

  # ...and another plugin that can be fetched from Puppet with "puppet://"
  scp_to(host, './spec/fixtures/plugins/logstash-output-cowthink-5.0.0.gem', "#{codedir}/modules/logstash/files/")

  # ...and yet another plugin, this time packaged as an offline installer
  scp_to(host, './spec/fixtures/plugins/logstash-output-cowsay-5.0.0.zip', "#{codedir}/modules/logstash/files/")

  # Provide a config file template.
  scp_to(host, './spec/fixtures/configfile/null-output.conf', "#{codedir}/modules/logstash/files/")

  # ...and  a config file template.
  scp_to(host, './spec/fixtures/templates/configfile-template.erb', "#{codedir}/modules/logstash/templates/")
end

RSpec.configure do |c|
  # module_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  # module_name = module_root.split('/').last

  # Readable test descriptions
  c.formatter = :documentation
end
