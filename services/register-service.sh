#!/bin/bash

err() {
    echo "$@" 1>&2
}


register_to_discovery_service() {
    local svcname
    local svcport
    local domain

    svcname="$1"
    svcport=$2
    domain=${3:-service.consul}
    
    
    if [[ ! $svcname ]]; then
        err "missing required argument: service name"
        return 1
    fi

    if [[ ! $svcport ]]; then
        err "missing required argument: service port"
        return 1
    fi


    local discourl
    discourl="http://consul.$domain:8500/v1/agent/service/register"
    
    curl -X POST \
         -H 'Content-Type: application.json'\
         -d ' { "ID": "'$svcname'", "Name": "'$svcname'", "Tags": [], "Port": '$svcport' }'\
         $discourl  
}


register_to_router() {
    local svcname
    local svcport
    local domain

    svcname="$1"
    svcport=$2
    domain=${3:-service.consul}
    

    if [[ ! $svcname ]]; then
        err "missing required argument: service name"
        return 1
    fi
    
    if [[ ! $svcport ]]; then
        err "missing required argument: service port"
        return 1
    fi

    local svcdomain
    svcdomain="$svcname.$domain"
    
    local routerurl
    routerurl="http://consul.$domain:8182/v2"

    curl -X POST \
         -H 'Content-Type: application/json' \
         -d '{ "Host": { "Name": "'$svcdomain'" } }' \
         $routerurl/hosts
    
    curl -X POST \
         -H 'Content-Type: application/json' \
         -d '{ "Backend": { "Id": "'$svcname'", "Type": "http" } }' \
         $routerurl/backends
    
    curl -X POST \
         -H 'Content-Type: application/json' \
         -d '{ "Frontend": { "Id": "'$svcname'", "Route": "Path(`/`)", "Type": "http", "BackendId": "'$svcname'", "Settings": { "Hostname": "'$svcdomain'" } } }' \
         $routerurl/frontends
    
    curl -X POST \
         -H 'Content-Type: application/json' \
         -d '{ "Listener": { "Id": "'$svcname'", "Protocol": "http", "Address": { "Network": "tcp", "Address": "0.0.0.0:'$svcport'" } } }' \
         $routerurl/listeners
}


register_to_gateway() {
    local svcname
    local svcport
    local domain

    svcname="$1"
    svcport=$2
    domain=${3:-service.consul}
    
    if [[ ! $svcname ]]; then
        err "missing required argument: service name"
        return 1
    fi
    
    if [[ ! $svcport ]]; then
        err "missing required argument: service port"
        return 1
    fi
    
    local svcdomain
    svcdomain="$svcname.$domain"
    
    local routerurl
    routerurl="http://vulcand.$domain:8182/v2"

    local gwurl
    gwurl="http://kong.$domain:8001/apis/"

    curl -i -X POST \
         --url $gwurl \
         -d 'name=web' \
         -d 'upstream_url=http://vulcand.'$domain':'$svcport \
         -d 'request_host='$svcdomain \
         -d 'preserve_host=true'
}


main() {
    local svcname
    local svcport
    local domain
    
    
    for i in "$@"
    do
        case $i in
            --service-name=*)
                svcname="${i#*=}"
                shift
                ;;
            --service-port=*)
                svcport=${i#*=}
                shift
                ;;
            --domain)
                domain="${i#*=}"
                shift
                ;;
            --help)
                echo "./register-service.sh --service-name=SVCNAME --service-port=SVCPORT"
                exit 0
                ;;
            *)
                ;;
        esac
    done

    register_to_router $svcname $svcport $domain
    register_to_discovery_service $svcname $svcport $domain
    register_to_gateway $svcname $svcport $domain
}

main "$@"
exit 0
