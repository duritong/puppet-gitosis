class gitosis::daemon::vhosts inherits gitosis::daemon {
  file{'/srv/git':
    require => User['gitosisd'],
  }
  if hiera('git_daemon',true) == 'service' {
    File['/etc/sysconfig/git-daemon']{
      source => [ "puppet:///modules/site_gitosis/sysconfig/${::fqdn}/git-daemon.vhosts",
                  "puppet:///modules/site_gitosis/sysconfig/git-daemon.vhosts",
                  "puppet:///modules/gitosis/sysconfig/git-daemon.vhosts" ],
    }
  } elsif hiera('git_daemon',true) != false {
    Xinetd::File['git']{
      source => [ "puppet:///modules/site_gitosis/xinetd.d/${::fqdn}/git.vhosts",
                  "puppet:///modules/site_gitosis/xinetd.d/git.vhosts",
                  "puppet:///modules/gitosis/xinetd.d/git.vhosts" ],
      require +> User['gitosisd'],
    }
  }
  if hiera('git_daemon',true) == false {
    File['/srv/git']{
      ensure => absent,
      purge => true,
      force => true,
      recurse => true,
    }
  } else {
    File['/srv/git']{
      ensure => directory,
      owner => root,
      group => gitosisd,
      mode => 0750
    }
  }
}
