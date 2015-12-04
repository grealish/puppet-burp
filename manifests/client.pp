# == Define burp::client
#
# This defined type configures a BURP backup client.
#
# === Parameters
#
# [*ca_dir*]
#   Default: /var/lib/burp/CA-client-${name}
#   Directory where all client certificate related files are saved to.
#
# [*clientconfig_tag*]
#   Default: $server
#   Puppet tag which gets assigned to `::burp::clientconfig` resources for
#   later collection on the BURP server using exported resources.
#
# [*configuration*]
#   Default: {}
#   Hash of client configuration directives. See man page of BURP, section
#   "CLIENT CONFIGURATION FILE OPTIONS", for a detailed list of all possible
#   values. A big bunch of default values are already prepared (see code below).
#   Values defined in this hash will get merged and will override the default
#   parameters!
#
# [*cron_minute*]
#   Default: */5
#   Minute part of the BURP backup client cron job.
#
# [*cron_mode*]
#   Default: t
#   Mode to run the BURP backup client in. Possible values:
#   b (backup) or t (timed backup).
#
# [*cron_randomise*]
#   Default: 60
#   When running a timed backup (`t` mode), sleep for a random number of seconds (between 0 and the  number  given)
#   before contacting the server.
#
# [*manage_ca_dir*]
#   Default: true
#   Manage CA directory or not.
#
# [*manage_clientconfig*]
#   Default: true
#   Manage clientconfig or not. If true, an exported resource of type
#   `::burp::clientconfig` will be created and the tag `clientconfig_tag`
#   assigned. Can be collected on the BURP backup server.
#
# [*manage_cron*]
#   Default: true
#   Manage BURP backup client cron job.
#
# [*manage_extraconfig*]
#   Default: true
#   Manage BURP backup client extra configuration. If set to true, a extra
#   configuration file will be included in the main client configuration
#   file. This extra configuration file can be filled with the `burp::extraconfig`
#   defined type.
#
# [*server*]
#   Default: "backup.${::domain}"
#   BURP backup server address.
#
# [*password*]
#   Default: fqdn_rand_string(10)
#   Password to authenticate the client on the BURP backup server.
#
# === Authors
#
# Tobias Brunner <tobias.brunner@vshn.ch>
#
# === Copyright
#
# Copyright 2015 Tobias Brunner, VSHN AG
#
define burp::client (
  $ca_dir = "/var/lib/burp/CA-client-${name}",
  $clientconfig_tag = undef,
  $configuration = {},
  $cron_minute = '*/5',
  $cron_mode = 't',
  $cron_randomise = '60',
  $manage_ca_dir = true,
  $manage_clientconfig = true,
  $manage_cron = true,
  $manage_extraconfig = true,
  $server = "backup.${::domain}",
  $password = fqdn_rand_string(10),
) {

  ## Some input validations
  validate_re($cron_mode,['^b$','^t$'],'cron_mode must be one of "b" or "t"')

  ## Default configuration parameters for BURP client
  # parameters coming from a default BURP installation (most of them)
  $_default_configuration = {
    'ca_burp_ca'            => '/usr/sbin/burp_ca',
    'ca_csr_dir'            => $ca_dir,
    'cname'                 => $::fqdn,
    'cross_all_filesystems' => 0,
    'cross_filesystem'      => '/home',
    'mode'                  => 'client',
    'password'              => $password,
    'pidfile'               => "/tmp/burp.client.${name}.pid",
    'port'                  => '4971',
    'progress_counter'      => 1,
    'server'                => $server,
    'server_can_restore'    => 0,
    'ssl_cert'              => "${ca_dir}/ssl_cert-client.pem",
    'ssl_cert_ca'           => "${ca_dir}/ssl_cert_ca.pem",
    'ssl_key'               => "${ca_dir}/ssl_cert-client.key",
    'ssl_peer_cn'           => $server,
    'stdout'                => 1,
    'syslog'                => 0,
  }
  $_configuration = merge($_default_configuration,$configuration)

  ## Write client configuration file
  if $manage_extraconfig {
    $_include = "${::burp::config_dir}/${name}-extra.conf"
    concat { "${::burp::config_dir}/${name}-extra.conf":
      ensure  => present,
    }
    concat::fragment { 'burpclient_extra_header':
      target  => "${::burp::config_dir}/${name}-extra.conf",
      content => "# THIS FILE IS MANAGED BY PUPPET\n# Contains additional client configuration\n",
      order   => 01,
    }
  }
  file { "${::burp::config_dir}/${name}.conf":
    ensure  => file,
    content => template('burp/burp.conf.erb'),
    require => Class['::burp::config'],
  }

  ## Prepare CA dir
  if $manage_ca_dir {
    file { $ca_dir:
      ensure => directory,
    }
  }

  ## Cronjob
  if $manage_cron {
    cron { "burp_client_${name}":
      command => "/usr/sbin/burp -c ${::burp::config_dir}/${name}.conf -a ${cron_mode} -q ${cron_randomise} >/dev/null 2>&1",
      user    => 'root',
      minute  => $cron_minute,
    }
  }

  ## Exported resource for clientconfig
  if $manage_clientconfig {
    if $configuration['cname'] {
      $_clientname = $configuration['cname']
    } else {
      $_clientname = $::fqdn
    }
    if $clientconfig_tag == undef {
      $_clientconfig_tag = $server
    } else {
      $_clientconfig_tag = $clientconfig_tag
    }
    @@::burp::clientconfig { $_clientname:
      password => $password,
      tag      => $_clientconfig_tag,
    }
  }

}