# manifests/hooks.pp

class gitosis::hooks {
    file{'/opt/git-hooks':
        source => "puppet://$server/modules/gitosis/hooks",
        recurse => true,
        purge => true,
        force => true,
        owner => root, group => 0, mode => 0755;
    }
}
