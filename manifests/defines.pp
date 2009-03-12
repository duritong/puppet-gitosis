# manifests/defines.pp

# if you don't like to run a git-daemon for the gitosis daemon
# please set the global variabl $gitosis_daemon to false.

define gitosis::repostorage(
    $basedir = 'absent',
    $uid = 'absent',
    $gid = 'uid',
    $initial_admin_pubkey,
    $sitename = 'absent',
    $git_vhost = 'absent',
    $gitweb = true
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
        case $git_vhost {
            'absent': {
                file{'/srv/git':
                    ensure => "${real_basedir}/repositories",
                }     
            }
            default: {
                include gitosis::daemon::vhosts
                file{"/srv/git/${git_vhost}":
                    ensure => "${real_basedir}/repositories",
                }
            }
        }
        exec{"add_${name}_to_repos_group":
            command => "usermod -a -G ${name} gitosisd",
            unless => "groups gitosisd | grep -q ' ${name}'",
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
                        exec{'add_lighttpd_to_repos_group':
                            command => "usermod -a -G ${name} lighttpd",
                            unless => "groups lighttpd | grep -q ' ${name}'",
                            require => Package['lighttpd'],
                            notify =>  Service['lighttpd'],
                        }
                    }
                    default: { fail("no supported \$gitweb_webserver defined on ${fqdn}, so can't do git::web::repo: ${name}") }
                }
            }   
        }
    }
}

# you can define wether to receive post-receive emails and to which address
# name: name of the git repo we'd like to have emailnotification
# gitosis_repo: the gitosis_repo in which the git repo is contained
# basedir: basedir of the gitosis_repo. If absent default schema we'll be used.
# mailinglist: the mail address we'd like to spam with commit emails
# announcelist: the mail address we'd like to spam if annotated tags have been pushed. Options:
#   - mailinglist: the same as the mailinglist (*Default*)
#   - absent: unset
#   - other string: the address
# envelopesender: wether we'd like to set an envelope sender
# emailprefix: which prefix a subject should have. Options:
#   - absent: will be prefixed with [SCM] 
#   - name: use the name of the git repo to prefix: [$gitrepo_name] (*Default*)
#   - other string: use this string in brackets: [$emailprefix]
# generatepatch: wether to generate a patch or not
define gitosis::emailnotification(
    $gitosis_repo,
    $basedir = 'absent',
    $mailinglist,
    $announcelist = 'mailinglist',
    $envelopesender = 'absent',
    $emailprefix = 'name',
    $generatepatch = true
){

    include gitosis::hooks

    $repodir = $basedir ? {
        'absent' => "/home/${gitosis_repo}/repositories/${name}.git",
        default => "${basedir}/repositories/${name}.git"
    }
    $repoconfig = "${repodir}/config"

    file{"${repodir}/hooks/post-receive-email":
        ensure => '/opt/git-hooks/post-receive-email',
        force => true,
        require => File['/opt/git-hooks'],
    }

    
    Exec {
        onlyif => "test -e ${repoconfig}",
        require => File["${repodir}/hooks/post-receive-email"],
    }

    exec{"git config --file ${repoconfig} hooks.mailinglist ${mailinglist}": }

    case $announcelist {
        'mailinglist': { 
            $real_announcelist = $mailinglist 
            $real_announcelist_set = ''
        }
        'absent': {
            $real_announcelist = ''
            $real_announcelist_set = '--unset'
        }
        default: {
            $real_announcelist = $announcelist
            $real_announcelist_set = ''
        }
    }
    exec{"git config --file ${repoconfig} ${real_announcelist_set} hooks.announcelist ${real_announcelist}": }

    if $envelopesender == 'absent' { 
            $real_envelopesender = ''
            $real_envelopesender_set = '--unset'
    } else {
            $real_envelopesender = $envelopesender
            $real_envelopesender_set = ''
    }
    exec{"git config --file ${repoconfig} ${real_envelopesender_set} hooks.envelopesender ${real_envelopesender}": }

    case $emailprefix {
        'name': {
            $real_emailprefix = "'[${name}]'"
            $real_emailprefix_set = ''
        }
        'absent': {
            $real_emailprefix = ''
            $real_emailprefix_set = '--unset'
        }
        default: {
            $real_emailprefix = "'[${emailprefix}]'"
            $real_emailprefix_set = ''
        }
    }
    exec{"git config --file ${repoconfig} ${real_emailprefix_set} hooks.emailprefix ${real_emailprefix}": }

    if $generatepatch {
        $real_generatepatch = true
        $real_generatepatch_set = ''
    } else {
        $real_generatepatch = ''
        $real_generatepatch_set = '--unset'
    }
    exec{"git config --file ${repoconfig} ${real_generatepatch_set} hooks.generatepatch ${real_generatepatch}": }
}
