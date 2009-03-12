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
    $admins = 'absent',
    $admins_generatepatch = true,
    $admins_sender = false,
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

    gitosis::emailnotification{"gitosis-admin_${name}":
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

# you can define wether to receive post-receive emails and to which address
# name: name of the git repo we'd like to have emailnotification
# gitosis_repo: the gitosis_repo in which the git repo is contained
# basedir: basedir of the gitosis_repo. If absent default schema we'll be used.
# mailinglist: the mail address we'd like to spam with commit emails
# announcelist: the mail address we'd like to spam if annotated tags have been pushed. Options:
#   - mailinglist: the same as the mailinglist (*Default*)
#   - absent: unset
#   - other string: the address
# envelopesender: wether we'd like to set an envelope sender. Absent: false
# emailprefix: which prefix a subject should have. Options:
#   - absent: will be prefixed with [SCM] 
#   - name: use the name of the git repo to prefix: [$gitrepo_name] (*Default*)
#   - other string: use this string in brackets: [$emailprefix]
# generatepatch: wether to generate a patch or not
define gitosis::emailnotification(
    $gitrepo = 'absent',
    $ensure = present,
    $gitosis_repo,
    $basedir = 'absent',
    $mailinglist,
    $announcelist = 'mailinglist',
    $envelopesender = false,
    $emailprefix = 'name',
    $generatepatch = true
){

    include gitosis::hooks

    if $gitrepo == 'absent' {
        $real_gitrepo = $name
    } else { 
        $real_gitrepo = $gitrepo
    }

    $repodir = $basedir ? {
        'absent' => "/home/${gitosis_repo}/repositories/${real_gitrepo}.git",
        default => "${basedir}/repositories/${real_gitrepo}.git"
    }
    $repoconfig = "${repodir}/config"

    file{"${repodir}/hooks/post-receive":
        ensure => file,
        owner => root, group => 0, mode => 0755;
    }
    line{"emailnotification_hook_for_${name}":
        ensure => $ensure,
        line => '. /opt/git-hooks/post-receive-email',
        file => "${repodir}/hooks/post-receive",
        require => [ File['/opt/git-hooks'], File["${repodir}/hooks/post-receive"] ],
    }

    exec{"git config --file ${repoconfig} hooks.mailinglist ${mailinglist}": 
        unless => "git config --file ${repoconfig} hooks.mailinglist | grep -qE '^${mailinglist}$'",
    }

    case $announcelist {
        'mailinglist': { 
            exec{"git config --file ${repoconfig} hooks.announcelist ${mailinglist}": 
                unless => "git config --file ${repoconfig} hooks.announcelist | grep -qE '^${mailinglist}$'",
                onlyif => "test -e ${repoconfig}",
                require => Line["emailnotification_hook_for_${name}"],
            }
        }
        'absent': {
            exec{"git config --file ${repoconfig} hooks.announcelist": 
                onlyif => [ "test -e ${repoconfig}", "git config --file ${repoconfig} hooks.announcelist > /dev/null"],
                require => Line["emailnotification_hook_for_${name}"],
            }
            
        }
        default: {
            exec{"git config --file ${repoconfig} hooks.announcelist ${announcelist}": 
                unless => "git config --file ${repoconfig} hooks.announcelist | grep -qE '^${announcelist}$'",
                onlyif => "test -e ${repoconfig}",
                require => Line["emailnotification_hook_for_${name}"],
            }
        }
    }

    if $envelopesender { 
        exec{"git config --file ${repoconfig} hooks.envelopesender ${envelopesender}":
            unless => "git config --file ${repoconfig} hooks.envelopesender | grep -qE '^${envelopesender}$'",
            onlyif => "test -e ${repoconfig}",
            require => Line["emailnotification_hook_for_${name}"],
        }
    } else {
        exec{"git config --file ${repoconfig} hooks.envelopesender --unset":
            onlyif => [ "test -e ${repoconfig}", "git config --file ${repoconfig} hooks.envelopesender > /dev/null" ],
            require => Line["emailnotification_hook_for_${name}"],
        }
    }

    case $emailprefix {
        'name': {
            exec{"git config --file ${repoconfig} hooks.emailprefix '[${real_gitrepo}] '":
              unless => "git config --file ${repoconfig} hooks.emailprefix | grep -qE '[${real_gitrepo}] '",
              onlyif => "test -e ${repoconfig}",
              require => Line["emailnotification_hook_for_${name}"],
            }
        }
        'absent': {
            exec{"git config --file ${repoconfig} hooks.emailprefix --unset":
                onlyif => [ "test -e ${repoconfig}", "git config --file ${repoconfig} hooks.emailprefix > /dev/null" ],
                require => Line["emailnotification_hook_for_${name}"],
            }
        }
        default: {
            exec{"git config --file ${repoconfig} hooks.emailprefix '[${emailprefix}] '":
              unless => "git config --file ${repoconfig} hooks.emailprefix | grep -qE '[${emailprefix}] '",
              onlyif => "test -e ${repoconfig}",
              require => Line["emailnotification_hook_for_${name}"],
            }
        }
    }

    if $generatepatch {
        exec{"git config --file ${repoconfig} hooks.generatepatch ${generatepatch}": 
            unless => "git config --file ${repoconfig} hooks.generatepatch | grep -qE '^${generatepatch}$'",
            onlyif => "test -e ${repoconfig}",
            require => Line["emailnotification_hook_for_${name}"],
        }
    } else {
        exec{"git config --file ${repoconfig} hooks.generatepatch --unset":
            onlyif => [ "test -e ${repoconfig}" ,"git config --file ${repoconfig} hooks.generatepatch > /dev/null" ], 
            require => Line["emailnotification_hook_for_${name}"],
        }
    }
}
