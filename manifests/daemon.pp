# daemon stuff for gitosis
class gitosis::daemon {
  class{'git::daemon':
    use_shorewall => hiera('use_shorewall',false),
  }
  include xinetd

  file{'/srv/git':
    ensure        => directory,
    seltype       => 'git_system_content_t',
    owner         => root,
    group         => 0,
    mode          => '0644',
    recurse       => true,
    purge         => true,
    force         => true,
    recurselimit  => 1,
    require       => Package['git-daemon'],
  }
  augeas{'enable_git_daemon':
    context => '/files/etc/xinetd.d/git/service',
    changes => [
      'set disable no',
      'set user gitosisd',
      'rm server_args/value',
      'set server_args/value[1] --interpolated-path=/srv/git/%H/%D',
      'set server_args/value[2] --syslog',
      'set server_args/value[3] --inetd',
    ],
    notify  => Service['xinetd'],
  }

  $shell = $::operatingsystem ? {
    debian  => '/usr/sbin/nologin',
    ubuntu  => '/usr/sbin/nologin',
    default => '/sbin/nologin'
  }
  user::managed{'gitosisd':
    name_comment  => 'gitosis git-daemon user',
    managehome    => false,
    homedir       => '/srv/git',
    shell         => $shell,
  }
}
