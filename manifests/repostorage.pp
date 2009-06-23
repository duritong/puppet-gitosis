# manifests/defines.pp

# if you don't like to run a git-daemon for the gitosis daemon
# please set the global variabl $gitosis_daemon to false.

# admins: if set to an emailaddress we will add a email diff hook
# admins_generatepatch: wether to include a patch
# admins_sender: which sender to use
define gitosis::repostorage(
    $basedir = 'absent',
    $uid = 'absent',
    $gid = 'uid',
    $password = 'absent',
    $password_crypted = true,
    $admins = 'absent',
    $admins_generatepatch = true,
    $admins_sender = false,
    $initial_admin_pubkey,
    $sitename = 'absent',
    $git_vhost = 'absent',
    $gitweb = true
){
    include ::gitosis

    $real_basedir = $basedir ? {
        'absent' => "/home/${name}",
        default => $basedir
    }

    user::managed{"$name":
        homedir => $real_basedir,
        uid => $uid,
        gid => $gid,
        password => $password,
        password_crypted => $password_crypted,
    }

    file{"${real_basedir}/initial_admin_pubkey.puppet":
        content => "${initial_admin_pubkey}\n",
        require => User[$name],
        owner => $name, group => $name, mode => 0600;
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
        owner => $name, group => $name, mode => 0755;
    } 

    case $gitosis_daemon {
        '': { $gitosis_daemon = true }
    }
    if $gitosis_daemon {
        include ::gitosis::daemon
        case $git_vhost {
            'absent': {
                file{'/srv/git':
                    ensure => "${real_basedir}/repositories",
                }     
            }
            default: {
                include ::gitosis::daemon::vhosts
                file{"/srv/git/${git_vhost}":
                    ensure => "${real_basedir}/repositories",
                }
            }
        }
        augeas{"add_gitosisd_to_group_${name}":
          context => "/files/etc/group",
          changes => [ "ins user after ${name}/user[last()]",
                       "set ${name}/user[last()]  gitosisd" ],
          onlyif => "match ${name}/*[../user='gitosisd'] size == 0",
          require => [ User['gitosisd'], Group[$name] ],
          notify =>  Service['git-daemon'],
        }

    }

    if $gitweb {
        case $git_vhost {
            'absent': { fail("can't do gitweb if \$git_vhost isn't set for ${name} on ${fqdn}") }
            default: {
                git::web::repo{$git_vhost:
                    projectroot => "${real_basedir}/repositories",
                    projects_list => "${real_basedir}/gitosis/projects.list",
                    sitename => sitename,
                }
                case $gitweb_webserver {
                    'lighttpd': { 
                        augeas{"add_lighttpd_to_repos_group_${name}":
                            context => "/files/etc/group",
                            changes => [ "ins user after ${name}/user[last()]",
                                         "set ${name}/user[last()]  lighttpd" ],
                            onlyif => "match ${name}/*[../user='lighttpd'] size == 0",
                            require => [ Package['lighttpd'], Group[$name] ],
                            notify =>  Service['lighttpd'],
                        }
                    }
                    'apache': {
                        augeas{"add_apache_to_repos_group_${name}":
                            context => "/files/etc/group",
                            changes => [ "ins user after ${name}/user[last()]",
                                         "set ${name}/user[last()]  apache" ],
                            onlyif => "match ${name}/*[../user='apache'] size == 0",
                            require => [ Package['apache'], Group[$name] ],
                            notify =>  Service['apache'],
                        }
                    }
                    default: { fail("no supported \$gitweb_webserver defined on ${fqdn}, so can't do git::web::repo: ${name}") }
                }
            }   
        }
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
}

