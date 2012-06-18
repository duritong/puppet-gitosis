# if you don't like to run a git-daemon for the gitosis daemon
# please set the hiera variable git_daemon to false.
# admins: if set to an emailaddress we will add a email diff hook
# admins_generatepatch: wether to include a patch
# admins_sender: which sender to use
#
# logmode:
#   - default: Do normal logging including ips
#   - anonym: Don't log ips
define gitosis::repostorage(
  $ensure = 'present',
  $basedir = 'absent',
  $uid = 'absent',
  $gid = 'uid',
  $group_name = 'absent',
  $logmode = 'default',
  $password = 'absent',
  $password_crypted = true,
  $admins = 'absent',
  $admins_generatepatch = true,
  $admins_sender = false,
  $initial_admin_pubkey = 'absent',
  $sitename = 'absent',
  $git_vhost = 'absent',
  $manage_user_group = true,
  $allowdupe_user = false,
  $gitweb = true,
  $nagios_check_code = 'OK'
){
  if ($ensure == 'present') and ($initial_admin_pubkey == 'absent') {
    fail("You need to pass \$initial_admin_pubkey if repostorage ${name} should be present!")
  }
  include ::gitosis

  $real_basedir = $basedir ? {
    'absent' => "/home/${name}",
    default => $basedir
  }

  $real_group_name = $group_name ? {
    'absent' => $name,
    default => $group_name
  }

  user::managed{$name:
    ensure => $ensure,
    homedir => $real_basedir,
    allowdupe => $allowdupe_user,
    uid => $uid,
    gid => $gid,
    manage_group => $manage_user_group,
    password => $password ? {
        'trocla' => trocla("gitosis_${trocla}",'sha512crypt'),
        default => $password
    },
    password_crypted => $password_crypted,
  }

  include ::gitosis::gitaccess
  augeas{"manage_${name}_in_group_gitaccess":
    context => "/files/etc/group",
    require => [ Group['gitaccess'], User::Managed[$name] ],
  }
  if $ensure == 'present' {
    file{"${real_basedir}/initial_admin_pubkey.puppet":
      content => "${initial_admin_pubkey}\n",
      require => User[$name],
      owner => $name, group => $real_group_name, mode => 0600;
    }
    exec{"create_gitosis_${name}":
      command => "env -i gitosis-init < initial_admin_pubkey.puppet",
      unless => "test -d ${real_basedir}/repositories",
      cwd => "${real_basedir}",
      user => $name,
      require => [ Package['gitosis'], File["${real_basedir}/initial_admin_pubkey.puppet"] ],
    }

    file{"${real_basedir}/repositories/gitosis-admin.git/hooks/post-update":
      require => Exec["create_gitosis_${name}"],
      owner => $name, group => $real_group_name, mode => 0755;
    }

    ::gitosis::emailnotification{"gitosis-admin_${name}":
      gitrepo => "gitosis-admin",
      gitosis_repo => $name,
      basedir => $real_basedir,
      envelopesender => $admins_sender,
      generatepatch => $admins_generatepatch,
      emailprefix => "${name}: gitosis-admin",
      require => File["${real_basedir}/repositories/gitosis-admin.git/hooks/post-update"],
    }
    if $admins != 'absent'  {
      Gitosis::Emailnotification["gitosis-admin_${name}"]{
            mailinglist => $admins,
        }
    } else {
      Gitosis::Emailnotification["gitosis-admin_${name}"]{
        ensure => absent,
        mailinglist => 'root',
      }
    }
    Augeas["manage_${name}_in_group_gitaccess"]{
      changes => [ "ins user after gitaccess/user[last()]",
                   "set gitaccess/user[last()]  ${name}" ],
      onlyif => "match gitaccess/*[../user='${name}'] size == 0",
    }
  } else {
    Augeas["manage_${name}_in_group_gitaccess"]{
      changes => "rm user gitaccess/user[.='${name}']",
    }
  }

  if hiera('git_daemon',true) {
    augeas{"manage_gitosisd_in_group_${real_group_name}":
      context => "/files/etc/group",
    }
  }
  case $git_vhost {
    'absent': { $git_vhost_link = '/srv/git' }
    default: {
      include ::gitosis::daemon::vhosts
      $git_vhost_link = "/srv/git/${git_vhost}"
    }
  }
  file{$git_vhost_link: }
  if hiera('git_daemon',true) and ($ensure == 'present') {
    include ::gitosis::daemon
    File[$git_vhost_link]{
      ensure => "${real_basedir}/repositories",
    }
    Augeas["manage_gitosisd_in_group_${real_group_name}"]{
      changes => [ "ins user after ${real_group_name}/user[last()]",
                   "set ${real_group_name}/user[last()]  gitosisd" ],
      onlyif => "match ${real_group_name}/*[../user='gitosisd'] size == 0",
      require => [ User['gitosisd'], Group[$real_group_name] ],
      notify =>  Service['git-daemon'],
    }
  } else {
    File[$git_vhost_link]{
      ensure => absent,
      force => true,
    }
    if hiera('git_daemon',true) {
      Augeas["manage_gitosisd_in_group_${real_group_name}"]{
        changes => "rm user ${real_group_name}/user[.='gitosisd']",
      }
    }
    if hiera('git_daemon',true) == false {
      include ::gitosis::daemon::disable
    }
  }

  $webuser = hiera('gitweb_webserver','none')
  if $webuser != 'none' {
    augeas{"manage_webuser_in_repos_group_${real_group_name}":
      context => "/files/etc/group",
    }
  }

  git::web::repo{$git_vhost:
    logmode => $logmode,
  }
  if $gitweb and $ensure == 'present' {
    case $git_vhost {
      'absent': { fail("can't do gitweb if \$git_vhost isn't set for ${name} on ${::fqdn}") }
      default: {
        if $webuser == 'none' {
          fail "You need to set gitweb_webserver for ${::fqdn} if you want to use gitwebs"
        }
        if defined(Package[$webuser]){
          Augeas["manage_webuser_in_repos_group_${real_group_name}"]{
            require => [ Package[$webuser], Group[$real_group_name] ],
          }
        } else {
          Augeas["manage_webuser_in_repos_group_${real_group_name}"]{
            require => Group[$real_group_name],
          }
        }
        if defined(Service[$webuser]){
          Augeas["manage_webuser_in_repos_group_${real_group_name}"]{
            notify => Service[$webuser],
          }
        }
        Git::Web::Repo[$git_vhost]{
          projectroot => "${real_basedir}/repositories",
          projects_list => "${real_basedir}/gitosis/projects.list",
          sitename => $sitename,
        }
        if $ensure == 'present' {
          Augeas["manage_webuser_in_repos_group_${real_group_name}"]{
            changes => [ "ins user after ${real_group_name}/user[last()]",
                         "set ${real_group_name}/user[last()]  ${webuser}" ],
            onlyif => "match ${real_group_name}/*[../user='${webuser}'] size == 0",
          }
        }
      }
    }
  } else {
    Git::Web::Repo[$git_vhost]{
      ensure => 'absent',
    }
    # if present is absent we removed the user anyway
    if ($present != 'absent') and ($webuser != 'none'){
      Augeas["manage_webuser_in_repos_group_${real_group_name}"]{
        changes => "rm ${real_group_name}/user[.='${webuser}']",
      }
    }
  }

  if hiera('use_nagios',false) {
    $check_hostname = $git_vhost ? {
      'absent' => $::fqdn,
      default => $git_vhost
    }
    sshd::nagios{"gitrepo_${name}":
      ensure => $ensure,
      port => 22,
      check_hostname => $check_hostname,
    }
    nagios::service{"git_${name}":
      ensure => $ensure ? {
        'present' => hiera('git_daemon',true) ? {
          false => 'absent',
          default => 'present'
        },
        default => $ensure
      },
      check_command => "check_git!${check_hostname}",
    }
    nagios::service::http{"gitweb_${name}":
      check_domain => $git_vhost,
      ensure => $ensure ? {
        'present' => $gitweb ? {
          false => 'absent',
          default => 'present'
        },
        default => $ensure
      },
      check_code => $nagios_check_code,
    }
  }
}

