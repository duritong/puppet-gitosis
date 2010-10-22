class gitosis::daemon::vhosts inherits gitosis::daemon {
  file{'/srv/git':
    ensure => directory,
    require => User['gitosisd'],
    owner => root, group => gitosisd, mode => 0750;
  }  
  if $git_daemon == 'service' {
    File['/etc/sysconfig/git-daemon']{
      source => [ "puppet:///modules/site-gitosis/sysconfig/${fqdn}/git-daemon.vhosts",
                  "puppet:///modules/site-gitosis/sysconfig/git-daemon.vhosts",
                  "puppet:///modules/gitosis/sysconfig/git-daemon.vhosts" ],
    }
  } else {
    File['/etc/xinetd.d/git']{
      source => [ "puppet:///modules/site-gitosis/xinetd.d/${fqdn}/git.vhosts",
                  "puppet:///modules/site-gitosis/xinetd.d/git.vhosts",
                  "puppet:///modules/gitosis/xinetd.d/git.vhosts" ],
      require +> User['gitosisd'],
    }
  }
}
