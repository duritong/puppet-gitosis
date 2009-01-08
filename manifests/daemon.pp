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
}
