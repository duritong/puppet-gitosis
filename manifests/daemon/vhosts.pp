class gitosis::daemon::vhosts inherits gitosis::daemon {
    File['/etc/sysconfig/git-daemon']{
        source => [ "puppet://$server/files/gitosis/sysconfig/${fqdn}/git-daemon.vhosts",
                    "puppet://$server/files/gitosis/sysconfig/git-daemon.vhosts",
                    "puppet://$server/gitosis/sysconfig/git-daemon.vhosts" ],
    }
}
