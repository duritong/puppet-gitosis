class gitosis::daemon::vhosts inherits gitosis::daemon {
    include git::daemon::vhosts

    Line['git-daemon_vhosts_yes']{
        ensure => absent,
    }
    Line['git-daemon_vhosts_yes']{
        ensure => present,
    }
}
