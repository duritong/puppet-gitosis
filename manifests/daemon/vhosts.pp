class gitosis::daemon::vhosts inherits gitosis::daemon {
    include git::daemon::vhosts

    Line['gitosis_vhosts_no']{
        ensure => absent,
    }
    Line['gitosis_vhosts_yes']{
        ensure => present,
    }
}
