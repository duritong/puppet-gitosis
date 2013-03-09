# daemon stuff for gitosis
class gitosis::daemon inherits git::daemon::extra {
  if hiera('git_daemon',true) == 'service' {
    File['/etc/sysconfig/git-daemon']{
      source => [ "puppet:///modules/site_gitosis/sysconfig/${::fqdn}/git-daemon",
                  'puppet:///modules/site_gitosis/sysconfig/git-daemon',
                  'puppet:///modules/gitosis/sysconfig/git-daemon' ],
      require +> User['gitosisd'],
    }
  } elsif hiera('git_daemon',true) != false {
    Xinetd::File['git']{
      source => [ "puppet:///modules/site_gitosis/xinetd.d/${::fqdn}/git",
                  'puppet:///modules/site_gitosis/xinetd.d/git',
                  'puppet:///modules/gitosis/xinetd.d/git' ],
      require +> User['gitosisd'],
    }
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
