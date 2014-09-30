# puppet-logstash

A Puppet module for managing and configuring [Logstash](http://logstash.net/).

[![Build Status](https://travis-ci.org/elasticsearch/puppet-logstash.png?branch=master)](https://travis-ci.org/elasticsearch/puppet-logstash)

## Versions

This overview shows you which Puppet module and Logstash version work together.

    ------------------------------------
    | Puppet module | Logstash         |
    ------------------------------------
    | 0.0.1 - 0.1.0 | 1.1.9            |
    ------------------------------------
    | 0.2.0         | 1.1.10           |
    ------------------------------------
    | 0.3.0 - 0.3.4 | 1.1.12 - 1.1.13  |
    ------------------------------------
    | 0.4.0 - 0.4.2 | 1.2.x - 1.3.x    |
    ------------------------------------
    | 0.5.0 - 0.5.1 | 1.4.1 - 1.4.2    |
    ------------------------------------

## Important notes

### 0.4.0

Please note that this a **backwards compatability breaking release**: in particular, the *[plugin](#Plugins)* syntax system has been removed entirely in favour of config files.

If you need any help please see the [support](#Support) section.


## Requirements

* Puppet 2.7.x or better.
* The [stdlib](https://forge.puppetlabs.com/puppetlabs/stdlib) Puppet library.
* The [file_concat](https://forge.puppetlabs.com/ispavailability/file_concat) Puppet library.

Optional:
* The [apt](https://forge.puppetlabs.com/puppetlabs/apt) Puppet library when using repo management on Debian/Ubuntu.
* The [zypprepo](https://forge.puppetlabs.com/darin/zypprepo) Puppet library when using repo management on SLES/SuSE

## Usage Examples

The minimum viable configuration ensures that the service is running and that it will be started at boot time:
**N.B.** you will still need to supply a configuration using either a configs parameter or the logstash::configfile define.

```puppet
     class { 'logstash': }
```

Specify a particular package (version) to be installed:

```puppet
     class { 'logstash':
       version => '1.3.3-1_centos'
     }
```

In the absense of an appropriate package for your environment it is possible to install from other sources as well.

http/https/ftp source:

```puppet
     class { 'logstash':
       package_url => 'http://download.elasticsearch.org/logstash/logstash/packages/centos/logstash-1.3.3-1_centos.noarch.rpm'
     }
```

`puppet://` source:

```puppet
     class { 'logstash':
       package_url => 'puppet:///path/to/logstash-1.3.3-1_centos.noarch.rpm'
     }
```

Local file source:

```puppet
     class { 'logstash':
       package_url => 'file:/path/to/logstash-1.3.3-1_centos.noarch.rpm'
     }
```

Attempt to upgrade Logstash if a newer package is detected (`false` by default):

```puppet
     class { 'logstash':
       autoupgrade => true
     }
```

Install everything but *disable* the service (useful for pre-configuring systems):

```puppet
     class { 'logstash':
       status => 'disabled'
     }
```

Under normal circumstances a modification to the Logstash configuration will trigger a restart of the service. This behaviour can be disabled:

```puppet
     class { 'logstash':
       restart_on_change => false
     }
```

Disable and remove Logstash entirely:

```puppet
     class { 'logstash':
       ensure => 'absent'
     }
```

Enable [Hiera Hash Merging](http://docs.puppetlabs.com/hiera/1/lookup_types.html#hash-merge) for parameter lookups. When using the [Hiera Automatic Parameter Lookup](http://docs.puppetlabs.com/hiera/1/puppet.html#automatic-parameter-lookup) functionality, only priority based lookups are supported. Setting this to enabled will override this behaviour to allow hash merging.

```puppet
     class { 'logstash':
       hieramerge => true
     }
```

## Contrib package installation

As of Logstash 1.4.0 plugins have been split into 2 packages.
To install the contrib package:

via the repository:

```puppet
     class { 'logstash':
       install_contrib => true
     }
```

via contrib_package_url:

```puppet
     class { 'logstash':
       install_contrib => true,
       contrib_package_url => 'http://download.elasticsearch.org/logstash/logstash/packages/centos/logstash-contrib-1.4.0-1_centos.noarch.rpm'
     }
```

with a version specified:

     class { 'logstash':
       install_contrib => true,
       contrib_version => '1.4.0'
     }



## Configuration Overview

The Logstash configuration can be supplied as a single static file or dynamically built from multiple smaller files or using raw content.

The basic usage is identical in either case: simply declare a `file` attribute as you would the [`content`](http://docs.puppetlabs.com/references/latest/type.html#file-attribute-content) attribute of the `file` type, meaning either direct content, template or a file resource:

```puppet
     logstash::configfile { 'configname':
       content => template('path/to/config.file')
     }
```
     or

```puppet
     logstash::configfile { 'configname':
       source => 'puppet:///path/to/config.file'
     }
```

     or if you want to use hiera to specify your configs, include the following create_resources call in your node manifest or in manifests/site.pp:

     $logstash_configs = hiera('logstash_configs', {})
     create_resources('logstash::configfile', $logstash_configs)

     and then include the following config within the corresponding hiera file:

     "logstash_configs": {
        "config-name": {
          "template": "logstash/config.file.erb"
        }
      }

      please note you'll have to create your logstash.conf.erb file and place it in the logstash module templates directory prior to using this method


To dynamically build a configuration, simply declare the `order` in which each section should appear - the lower the number the earlier it will appear in the resulting file (this should be a [familiar idiom](https://en.wikipedia.org/wiki/BASIC) for most).

```puppet
     logstash::configfile { 'input_redis':
       template => 'logstash/input_redis.erb',
       order   => 10
     }

     logstash::configfile { 'filter_apache':
       source => 'puppet:///path/to/filter_apache',
       order  => 20
     }

     logstash::configfile { 'output_es':
       template => 'logstash/output_es_cluster.erb'
       order   => 30
     }
```

You may alternatively specify a list of configfile directives via the hash parameter *configs* during the module load.
This allows storing the configuration data in hiera.

```puppet
     class { 'logstash':
       configs => {
         input_redis => {
            content => template('logstash/input_redis.erb'),
            order   => 10
          },
          filter_apache => {
            source => 'puppet:///path/to/filter_apache',
            order  => 20
          },
          output_es => {
            content => template('logstash/output_es_cluster.erb'),
            order   => 30
          },
       }
     }
```

The following example stores raw configuration settings in [Hiera (YAML)](http://docs.puppetlabs.com/hiera/1/puppet.html):

```yaml
logstash::configs:
  input_json:
    order   : 10
    content : |
      input {
        tcp {
          port  => 3333
          type  => "json-tcp"
          codec => "json"
        }
      }

  output_plain:
    order   : 20
    content : |
      output {
        file {
          codec           => "plain"
          flush_interval  => 2
          gzip            => false
          path            => "/var/log/logstash/test.log"
          workers         => 1
        }
      }
```

## Patterns

Many plugins (notably [Grok](http://logstash.net/docs/latest/filters/grok)) use *patterns*. While many are [included](https://github.com/logstash/logstash/tree/master/patterns) in Logstash already, additional site-specific patterns can be managed as well; where possible, you are encouraged to contribute new patterns back to the community.

**N.B.** As of Logstash 1.2 the path to the additional patterns needs to be configured explicitly in the Grok configuration.

```puppet
     logstash::patternfile { 'extra_patterns':
       source => 'puppet:///path/to/extra_pattern'
     }
```

By default the resulting filename of the pattern will match that of the source. This can be over-ridden:

```puppet
     logstash::patternfile { 'extra_patterns_firewall':
       source   => 'puppet:///path/to/extra_patterns_firewall_v1',
       filename => 'extra_patterns_firewall'
     }
```

## Plugins

Like the patterns above, Logstash comes with a large number of [plugins](http://logstash.net/docs/latest/); likewise, additional site-specific plugins can be managed as well.  Again, where possible, you are encouraged to contribute new plugins back to the community.

```puppet
     logstash::plugin { 'myplugin':
       ensure => 'present',
       type   => 'input',
       source => 'puppet:///path/to/my/custom/plugin.rb'
     }
```

By default the resulting filename of the plugin will match that of the source. This can be over-ridden:

```puppet
     logstash::plugin { 'myplugin':
       ensure   => 'present',
       type     => 'output',
       source   => 'puppet:///path/to/my/custom/plugin_v1.rb',
       filename => 'plugin.rb'
     }
```

## Java Install

Most sites will manage Java seperately; however, this module can attempt to install Java as well.

```puppet
     class { 'logstash':
       java_install => true
     }
```

Specify a particular Java package (version) to be installed:

```puppet
     class { 'logstash':
       java_install => true,
       java_package => 'packagename'
     }
```

## Repository management

Most sites will manage repositories seperately; however, this module can manage the repository for you.

```puppet
     class { 'logstash':
       manage_repo  => true,
       repo_version => '1.3'
     }
```

Note: When using this on Debian/Ubuntu you will need to add the [Puppetlabs/apt](http://forge.puppetlabs.com/puppetlabs/apt) module to your modules.

## Service Management

Currently only the basic SysV-style [init](https://en.wikipedia.org/wiki/Init) service provider is supported but other systems could be implemented as necessary (pull requests welcome).

### init

#### Defaults File

The *defaults* file (`/etc/defaults/logstash` or `/etc/sysconfig/logstash`) for the Logstash service can be populated as necessary. This can either be a static file resource or a simple key value-style  [hash](http://docs.puppetlabs.com/puppet/latest/reference/lang_datatypes.html#hashes) object, the latter being particularly well-suited to pulling out of a data source such as Hiera.

##### file source

```puppet
     class { 'logstash':
       init_defaults_file => 'puppet:///path/to/defaults'
     }
```

##### hash representation

```puppet
     $config_hash = {
       'LS_USER' => 'logstash',
       'LS_GROUP' => 'logstash',
     }

     class { 'logstash':
       init_defaults => $config_hash
     }
```

## Support

Need help? Join us in [#logstash](https://webchat.freenode.net?channels=%23logstash) on Freenode IRC or subscribe to the [logstash-users@googlegroups.com](https://groups.google.com/forum/#!forum/logstash-users) mailing list.
