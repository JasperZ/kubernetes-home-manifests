{
    kubernetes:: {
        namespace:: error "namespace is required",
        appNamePrefix:: error "namePrefix is required",
        labels:: error "labels is required",
        urbackup:: {
            resources:: {
                requests:: {
                    cpu:: "125m",
                    memory:: "128Mi",
                },
                limits:: {
                    cpu:: "250m",
                    memory:: "256Mi",
                },
            },
        },
    },
    application:: {
        urbackup:: {
            imageTag:: error "urbackup.imageTag is required",
            ip:: error "urbackup.ip is required"
        },
        persistentData:: {
            use:: error "persistentData.use is required",
            cheap:: {
                nfsServer:: error "persistentData.cheap.nfsServer is required",
                nfsRootPath:: error "persistentData.cheap.nfsRootPath is required",
            },
            expensive:: {
                nfsServer:: error "persistentData.expensive.nfsServer is required",
                nfsRootPath:: error "persistentData.expensive.nfsRootPath is required",
            },
        },
    },

    kube: {
        namespace: $.kubernetes.namespace,
        name: $.kubernetes.appNamePrefix,
        labels: $.kubernetes.labels,
        urbackup: {
            resources: {
                requests: {
                    cpu: $.kubernetes.urbackup.resources.requests.cpu,
                    memory: $.kubernetes.urbackup.resources.requests.memory,
                },
                limits: {
                    cpu: $.kubernetes.urbackup.resources.limits.cpu,
                    memory: $.kubernetes.urbackup.resources.limits.memory,
                },
            },
        },
    },
    app: {
        urbackup: {
            imageTag: $.application.urbackup.imageTag,
            ip: $.application.urbackup.ip,
        },
        persistentData: {
            use: $.application.persistentData.use,
        } + (
            if $.application.persistentData.use then {
                cheap: {
                    nfsServer: $.application.persistentData.expensive.nfsServer,
                    nfsRootPath: $.application.persistentData.cheap.nfsRootPath,
                },
                expensive: {
                    nfsServer: $.application.persistentData.expensive.nfsServer,
                    nfsRootPath: $.application.persistentData.expensive.nfsRootPath,
                },
            } else {}
        ),
    },
}
