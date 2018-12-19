define logstash::pipeline
(
  Hash $config                     = {},
  Optional[String] $content        = undef,
  Optional[String] $source         = undef,
  Optional[Stdlib::Unixpath] $path = undef,
  Optional[String] $id             = undef,
)
{
  unless $logstash::pipelines { fail('You must set base class `logstash`\'s `pipeline` parameter to `true` to use this defined type.') }
  if $content and $source { fail('You can\'t specify both `content` and `source`') }

  # overwrite keys in $config with values from $path and $id (if they're set).
  $real_config = $config + {
    'pipeline.id' => $id,
    'path.config' => $path,
    }.filter |$key, $val| { $val =~ NotUndef }

  unless 'pipeline.id' in $real_config { fail("logstash::pipeline ${title} is missing a pipeline id") }

  $yaml = [$real_config].to_yaml
  $yaml_without_header = join($yaml.split("\n")[1,-1],"\n")

  concat::fragment { "logstash pipeline ${title}":
    target  => '/etc/logstash/pipelines.yml',
    content => "${yaml_without_header}\n",
  }

  if $content or $source {
    if 'path.config' in $real_config {
      $real_path = $real_config['path.config']
    } else {
      fail('To use logstash::pipeline with `content` or `source`, the `config` hash must contain a `path.config` key or you must specify `path`')
    }
    logstash::configfile { "Config file for pipeline.id ${real_config['pipeline.id']}":
      content => $content,
      source  => $source,
      path    => $real_path,
    }
  }
}
