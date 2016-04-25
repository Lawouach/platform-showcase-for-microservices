#!/bin/bash

err() {
    echo "$@" 1>&2
}


deregister_from_discovery_service() {
    local svcname
    local domain

    svcname="$1"
    domain="${2:-service.consul}"

    if [[ ! $svcname ]]; then
        err "missing required argument: service name"
        return 1
    fi
    
    local discourl
    discourl="http://consul.$domain:8500/v1/agent/service/deregister"
    
    curl $discourl/$svcname
}


deregister_from_router() {
    local svcname
    local domain

    svcname="$1"
    domain="${2:-service.consul}"

    if [[ ! $svcname ]]; then
        err "missing required argument: service name"
        return 1
    fi

    local routerurl
    routerurl="http://vulcand.$domain:8182/v2"
    
    curl -X DELETE $routerurl/listeners/$svcname
    curl -X DELETE $routerurl/frontends/$svcname
    curl -X DELETE $routerurl/backends/$svcname
    curl -X DELETE $routerurl/hosts/$svcname.$domain
}


deregister_from_gateway() {
    local svcname
    local domain
    
    svcname="$1"
    domain="${2:-service.consul}"

    if [[ ! $svcname ]]; then
        err "missing required argument: service name"
        return 1
    fi
    
    local gwurl
    gwurl="http://kong.$domain:8001/apis"
    
    curl -X DELETE $gwurl/$svcname
}


main() {
    local svcname
    local svcid
    local domain
    
    for i in "$@"
    do
        case $i in
            --service-name=*)
                svcname="${i#*=}"
                shift
                ;;
            --domain)
                domain="${i#*=}"
                shift
                ;;
            --help)
                echo "./deregister-service.sh --service-name=SVCNAME"
                exit 0
                ;;
            *)
                ;;
        esac
    done

    deregister_from_gateway $svcname $domain
    deregister_from_discovery_service $svcname $domain
    deregister_from_router $svcname $domain
}

main "$@"
exit 0
