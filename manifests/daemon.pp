# daemon stuff for gitosis
class gitosis::daemon {
  class{'git::daemon::extra':
    use_shoreall => hiera('use_shorewall',false),
  }
  if hiera('git_daemon',true) == 'service' {
    Class['git::daemon::extra']{
      source => [ "puppet:///modules/site_gitosis/sysconfig/${::fqdn}/git-daemon",
                  'puppet:///modules/site_gitosis/sysconfig/git-daemon',
                  'puppet:///modules/gitosis/sysconfig/git-daemon' ],
    }
    User['gitosisd'] -> File['/etc/sysconfig/git-daemon']
  } elsif hiera('git_daemon',true) != false {
    Class['git::daemon::extra']{
      source => [ "puppet:///modules/site_gitosis/xinetd.d/${::fqdn}/git",
                  'puppet:///modules/site_gitosis/xinetd.d/git',
                  'puppet:///modules/gitosis/xinetd.d/git' ],
    }
    User['gitosisd'] -> Xinetd::File['git']
  }

  $shell = $::operatingsystem ? {
    debian  => '/usr/sbin/nologin',
    ubuntu  => '/usr/sbin/nologin',
    default => '/sbin/nologin'
  }
  user::managed{'gitosisd':
    name_comment  => 'gitosis git-daemon user',
    managehome    => false,
    homedir       => '/srv/git',
    shell         => $shell,
  }
}
