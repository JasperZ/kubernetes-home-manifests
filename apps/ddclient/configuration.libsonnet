{
    kubernetes:: {
        namespace:: error "namespace is required",
        appNamePrefix:: error "namePrefix is required",
        labels:: error "labels is required",
        ddclient:: {
            resources:: {
                requests:: {
                    cpu:: "125m",
                    memory:: "128Mi",
                },
                limits:: {
                    cpu:: "125m",
                    memory:: "128Mi",
                },
            },
        },
    },
    application:: {
        ddclient:: {
            imageTag:: error "imageTag is required",
            cloudflare:: {
                email:: error "ddclient.cloudflare.email is required",
                apiToken:: error "ddclient.cloudflare.apiToken is required",
                zone:: error "ddclient.cloudflare.zone is required",
                domains:: error "ddclient.cloudflare.domains is required",
            },
        },
    },

    kube: {
        namespace: $.kubernetes.namespace,
        name: $.kubernetes.appNamePrefix,
        labels: $.kubernetes.labels,
        ddclient: {
            resources: {
                requests: {
                    cpu: $.kubernetes.ddclient.resources.requests.cpu,
                    memory: $.kubernetes.ddclient.resources.requests.memory,
                },
                limits: {
                    cpu: $.kubernetes.ddclient.resources.limits.cpu,
                    memory: $.kubernetes.ddclient.resources.limits.memory,
                },
            },
        },
    },
    app: {
        ddclient: {
            imageTag: $.application.ddclient.imageTag,
            cloudflare: {
                email: $.application.ddclient.cloudflare.email,
                apiToken: $.application.ddclient.cloudflare.apiToken,
                zone: $.application.ddclient.cloudflare.zone,
                domains: $.application.ddclient.cloudflare.domains,
            },
        },
    },
}
