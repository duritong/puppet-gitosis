class gitosis::daemon {
    include git::daemon
    user::managed{'gitosisd':
        name_comment => "gitosis git-daemon user",
        managehome => false,
        homedir_mode => '/srv/git',
        shell => $operatingsystem ? {
            debian => '/usr/sbin/nologin',
            ubuntu => '/usr/sbin/nologin',
            default => '/sbin/nologin'
        },
   }
   line{'gitosis_vhosts_no':
        line => 'GITVHOSTS=no',
        file => '/etc/sysconfig/git-daemon',
        require => File['/etc/sysconfig/git-daemon'],
        notify => Service['git-daemon'],
   }
   line{'gitosis_vhosts_yes':
        line => 'GITVHOSTS=yes',
        file => '/etc/sysconfig/git-daemon',
        ensure => absent,
        require => File['/etc/sysconfig/git-daemon'],
        notify => Service['git-daemon'],
   }
}
