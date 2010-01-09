class gitosis::daemon::disable inherits gitosis::daemon {
  include git::daemon::disable
  File['/etc/sysconfig/git-daemon']{
    ensure => absent,
  }
  User::Managed['gitosisd']{
    ensure => 'absent'
  }
}
