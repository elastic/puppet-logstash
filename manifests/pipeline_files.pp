# This class manages pipeline configuration files for Logstash.
#
# @example Include this class to ensure its resources are available.
#   include logstash::pipeline_files
#
# @example Pass values to this class using an ENC with a specific path
#   pipeline2:
#     path: "/etc/logstash/conf.d/pipeline2.pipeline"
#     content: pipeline2
#
# @example Pass values to this class using an ENC without a specific path
#   pipeline2:
#     content: pipeline2
#
# @author https://github.com/XeonFibre
#
class logstash::pipeline_files {

  $pipeline_files = $logstash::pipeline_files

  if(!empty($pipeline_files)) {
    $pipeline_files.each |String $id, Hash $attributes| {
      logstash::configfile { $id:
        content => $attributes[content],
        path    => $attributes[path],
      }
    }
  }
}
