# manifests/init.pp - manage gitosis stuff
# Copyright (C) 2007 admin@immerda.ch
# GPLv3

class gitosis {
    case $operatingsystem {
        default: { include gitosis::base }
    }
}

class gitosis::base {
    include git
    include rsync
    include python::setuptools
    package{'gitosis':
        ensure => installed,
        require => [ Package['git'], Package['rsync'], Package['python::setuptools'] ],
    }
}

