#!/bin/bash

err() {
    echo "$@" 1>&2 
}


deregister_instance_from_router() {
    local svcid
    local svcname
    local domain

    svcid="$1"
    svcname="$2"
    domain="$3"

    if [[ ! $svcid ]]; then
        err "missing required argument: service id"
        return 1
    fi
    
    if [[ ! $svcname ]]; then
        err "missing required argument: service name"
        return 1
    fi
    
    local routerurl
    routerurl="http://consul.$domain:8182/v2"

    curl -X DELETE $routerurl/backends/$svcname/servers/$svcid
}


main() {
    local svcid
    local svcname
    local domain
    
    
    for i in "$@"
    do
        case $i in
            --service-id=*)
                svcid="${i#*=}"
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
                echo "./deregister-instance.sh --service-id=SVCID --service-name=SVCNAME"
                exit 0
            *)
                ;;
        esac
    done

    deregister_instance_from_router $svcid $svcname $domain
}

main "$@"
exit 0
