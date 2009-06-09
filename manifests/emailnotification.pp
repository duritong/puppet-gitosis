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
        ensure => $ensure ? {
            'present' => file,
            default => absent
        },
        owner => root, group => 0, mode => 0755;
    }
    line{"emailnotification_hook_for_${name}":
        ensure => $ensure,
        line => '. /opt/git-hooks/post-receive-email',
        file => "${repodir}/hooks/post-receive",
        require => [ File['/opt/git-hooks'], File["${repodir}/hooks/post-receive"] ],
    }

    if $ensure == 'present' {
        exec{"git config --file ${repoconfig} hooks.mailinglist ${mailinglist}":
            unless => "git config --file ${repoconfig} hooks.mailinglist | grep -qE '^${mailinglist}$'",
        }
    } else {
        exec{"git config --file ${repoconfig} --unset hooks.mailinglist":
            onlyif => "git config --file ${repoconfig} hooks.mailinglist > /dev/null",
        }
    }

    if $announcelist == 'mailinglist' and $ensure == 'present' {
        exec{"git config --file ${repoconfig} hooks.announcelist ${mailinglist}":
            unless => "git config --file ${repoconfig} hooks.announcelist | grep -qE '^${mailinglist}$'",
            onlyif => "test -e ${repoconfig}",
            require => Line["emailnotification_hook_for_${name}"],
        }
    } else {
        if $announcelist == 'absent' or $ensure != 'present' {
            exec{"git config --file ${repoconfig} --unset hooks.announcelist":
                onlyif => [ "test -e ${repoconfig}", "git config --file ${repoconfig} hooks.announcelist > /dev/null"],
                require => Line["emailnotification_hook_for_${name}"],
            }

        } else {
            exec{"git config --file ${repoconfig} hooks.announcelist ${announcelist}":
                unless => "git config --file ${repoconfig} hooks.announcelist | grep -qE '^${announcelist}$'",
                onlyif => "test -e ${repoconfig}",
                require => Line["emailnotification_hook_for_${name}"],
            }
        }
    }

    if $envelopesender and $ensure == 'present' {
        exec{"git config --file ${repoconfig} hooks.envelopesender ${envelopesender}":
            unless => "git config --file ${repoconfig} hooks.envelopesender | grep -qE '^${envelopesender}$'",
            onlyif => "test -e ${repoconfig}",
            require => Line["emailnotification_hook_for_${name}"],
        }
    } else {
        exec{"git config --file ${repoconfig} --unset hooks.envelopesender":
            onlyif => [ "test -e ${repoconfig}", "git config --file ${repoconfig} hooks.envelopesender > /dev/null" ],
            require => Line["emailnotification_hook_for_${name}"],
        }
    }

    if $emailprefix == 'name' and $ensure == 'present' {
        exec{"git config --file ${repoconfig} hooks.emailprefix '[${real_gitrepo}]'":
            unless => "git config --file ${repoconfig} hooks.emailprefix | grep -qE '[${real_gitrepo}]'",
            onlyif => "test -e ${repoconfig}",
            require => Line["emailnotification_hook_for_${name}"],
        }
    } else {
        if $emailprefix == 'absent' or $ensure != 'present' {
            exec{"git config --file ${repoconfig} --unset hooks.emailprefix":
                onlyif => [ "test -e ${repoconfig}", "git config --file ${repoconfig} hooks.emailprefix > /dev/null" ],
                require => Line["emailnotification_hook_for_${name}"],
            }
        } else {
            exec{"git config --file ${repoconfig} hooks.emailprefix '[${emailprefix}]'":
              unless => "git config --file ${repoconfig} hooks.emailprefix | grep -qE '[${emailprefix}]'",
              onlyif => "test -e ${repoconfig}",
              require => Line["emailnotification_hook_for_${name}"],
            }
        }
    }

    if $generatepatch and $ensure == 'present' {
        exec{"git config --file ${repoconfig} hooks.generatepatch ${generatepatch}":
            unless => "git config --file ${repoconfig} hooks.generatepatch | grep -qE '^${generatepatch}$'",
            onlyif => "test -e ${repoconfig}",
            require => Line["emailnotification_hook_for_${name}"],
        }
    } else {
        exec{"git config --file ${repoconfig} --unset hooks.generatepatch":
            onlyif => [ "test -e ${repoconfig}" ,"git config --file ${repoconfig} hooks.generatepatch > /dev/null" ],
            require => Line["emailnotification_hook_for_${name}"],
        }
    }
}
