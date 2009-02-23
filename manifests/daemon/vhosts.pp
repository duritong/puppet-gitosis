class gitosis::daemon::vhosts inherits gitosis::daemon {
    file{'/srv/git':
        ensure => directory,
        require => User['gitosisd'],
        owner => root, group => gitosisd, mode => 0750;
    }  
    File['/etc/sysconfig/git-daemon']{
        source => [ "puppet://$server/files/gitosis/sysconfig/${fqdn}/git-daemon.vhosts",
                    "puppet://$server/files/gitosis/sysconfig/git-daemon.vhosts",
                    "puppet://$server/gitosis/sysconfig/git-daemon.vhosts" ],
    }
}
