class gitosis::daemon inherits git::daemon {
  if $git_daemon == 'service' {
    File['/etc/sysconfig/git-daemon']{
      source => [ "puppet:///modules/site-gitosis/sysconfig/${fqdn}/git-daemon",
                  "puppet:///modules/site-gitosis/sysconfig/git-daemon",
                  "puppet:///modules/gitosis/sysconfig/git-daemon" ],
      require +> User['gitosisd'],
    }
  }
  user::managed{'gitosisd':
    name_comment => "gitosis git-daemon user",
    managehome => false,
    homedir => '/srv/git',
    shell => $operatingsystem ? {
      debian => '/usr/sbin/nologin',
      ubuntu => '/usr/sbin/nologin',
      default => '/sbin/nologin'
    },
   }
}
