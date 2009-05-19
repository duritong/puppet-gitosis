class gitosis::base {
    include git
    include rsync::client
    include python::setuptools
    package{'gitosis':
        ensure => installed,
        require => [ Package['git'], Package['rsync'], Package['python-setuptools'] ],
    }
}

