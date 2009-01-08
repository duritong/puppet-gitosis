# manifests/defines.pp

# if you don't like to run a git-daemon for the gitosis daemon
# please set the global variabl $gitosis_daemon to false.

define gitosis::repostorage(
    $basedir = 'absent',
    $uid = 'absent',
    $gid = 'uid',
    $initial_admin_pubkey,
    $daemon_vhost = 'absent'
){
    include gitosis

    $real_basedir = $basedir ? {
        'absent' => "/home/${name}",
        default => $basedir
    }

    user::managed{"$name":
        homedir => $real_basedir,
        uid => $uid,
        gid => $gid,
    }

    file{"${real_basedir}/initial_admin_pubkey.puppet":
        content => "${initial_admin_pubkey}\n",
        require => User[$name],
        owner => $name, group => $name, mode => 0600;
    }

    exec{"create_gitosis_${name}":
        command => "gitosis-init < ${real_basedir}/initial_admin_pubkey.puppet",
        unless => "test -d ${real_basedir}/repositories",
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
        include gitosis::daemon
        case $daemon_vhost {
            'absent': {
                file{'/srv/git':
                    ensure => "${real_basedir}/repositories",
                }     
                Line['gitvhosts_yes']{
                }
            }
            default: {
                include gitosis::daemon::vhosts
                file{'/srv/git':
                    ensure => directory,
                    require => User['gitosisd'],
                    owner => root, group => gitosisd, mode => 0750; 
                }
                file{"/srv/git/${daemon_vhost}":
                    ensure => "${real_basedir}/repositories",
                }
            }
        }
        exec{'add_ gitosisd_to_repos_group':
            command => "usermod -a -G ${name} gitosisd",
            unless => "groups gitosisd | grep -q ' ${name}'",
            require => User['gitosisd'],
            notify =>  Service['git-daemon'],
        }
    }
}
