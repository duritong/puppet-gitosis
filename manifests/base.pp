class gitosis::base {
  require git
  require rsync::client
  require python::setuptools
  package{'gitosis':
    ensure => installed,
  }
}

