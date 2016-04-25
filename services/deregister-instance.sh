#!/bin/bash

err() {
    echo "$@" 1>&2 
}


deregister_instance_from_router() {
    local instid
    local svcname
    local domain

    instid="$1"
    svcname="$2"
    domain="${3:-service.consul}"

    if [[ ! $instid ]]; then
        err "missing required argument: instance id"
        return 1
    fi
    
    if [[ ! $svcname ]]; then
        err "missing required argument: service name"
        return 1
    fi
    
    local routerurl
    routerurl="http://consul.$domain:8182/v2"

    curl -X DELETE $routerurl/backends/$svcname/servers/$instid
}


main() {
    local instid
    local svcname
    local domain
    
    
    for i in "$@"
    do
        case $i in
            --instance-id=*)
                instid="${i#*=}"
                shift
                ;;
            --service-name=*)
                svcname="${i#*=}"
                shift
                ;;
            --domain)
                domain="${i#*=}"
                shift
                ;;
            --help)
                echo "./deregister-instance.sh --instance-id=INSTID --service-name=SVCNAME"
                exit 0
                ;;
            *)
                ;;
        esac
    done

    deregister_instance_from_router $instid $svcname $domain
}

main "$@"
exit 0
