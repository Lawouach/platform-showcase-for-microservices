#!/bin/bash

err() {
    echo "$@" 1>&2
}


register_instance_to_router() {
    local instid
    local svcname
    local hostaddr
    local hostport
    local domain

    instid="$1"
    svcname="$2"
    hostaddr="$3"
    hostport=$4
    domain=${5:-service.consul}
    
    if [[ ! $instid ]]; then
        err "missing required argument: instance id"
        return 1
    fi
    
    if [[ ! $svcname ]]; then
        err "missing required argument: service name"
        return 1
    fi
    
    if [[ ! $hostaddr ]]; then
        err "missing required argument: service host address"
        return 1
    fi

    if [[ ! $hostport ]]; then
        err "missing required argument: service host port"
        return 1
    fi
    
    local routerurl
    routerurl="http://vulcand.$domain:8182/v2"

    curl -X POST \
         -H 'Content-Type: application/json' \
         -d '{ "Server": { "Id": "'$instid'", "URL": "http://'$hostaddr':'$hostport'" } }' \
         $routerurl/backends/$svcname/servers
}


main() {
    local svcname
    local instid
    local hostaddr
    local hostport
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
            --host-port=*)
                hostport=${i#*=}
                shift
                ;;
            --host-address=*)
                hostaddr="${i#*=}"
                shift
                ;;
            --domain)
                domain="${i#*=}"
                shift
                ;;
            --help)
                echo "./register-instance.sh --instance-id=INSTID --service-name=SVCNAME --host-address=SVCHOSTADDR --host-port=SVCHOSTPORT"
                exit 0
                ;;
            *)
                ;;
        esac
    done

    register_instance_to_router $instid $svcname $hostaddr $hostport $domain
}

main "$@"
exit 0
