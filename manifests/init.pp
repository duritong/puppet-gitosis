# manifests/init.pp - manage gitosis stuff
# Copyright (C) 2007 admin@immerda.ch
# GPLv3

class gitosis {
    case $operatingsystem {
        default: { include gitosis::base }
    }
}
