class gitosis::daemon inherits git::daemon {
    File['/etc/sysconfig/git-daemon']{
        source => [ "puppet://$server/files/gitosis/sysconfig/${fqdn}/git-daemon",
                    "puppet://$server/files/gitosis/sysconfig/git-daemon",
                    "puppet://$server/gitosis/sysconfig/git-daemon" ],
        require +> User['gitosisd'],
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
