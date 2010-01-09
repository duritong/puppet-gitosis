class gitosis::daemon::disable inherits gitosis::daemon {
  include ::git::daemon::disable
  User::Managed['gitosisd']{
    ensure => 'absent'
  }
}
