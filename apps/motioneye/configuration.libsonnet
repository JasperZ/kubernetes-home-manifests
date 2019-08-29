local motioneyeComponent = import "../../components/motioneye/motioneye.libsonnet";

{
    kubernetes:: {
        namespace:: error "namespace is required",
        appNamePrefix:: error "namePrefix is required",
        labels:: error "labels is required",
        motioneye:: {
            resources:: motioneyeComponent.configuration.kube.resources,
        },
    },
    application:: {
        motioneye:: {
            imageTag:: error "motioneye.imageTag is required",
            ip:: error "motioneye.ip is required"
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
        motioneye: {
            resources: {
                requests: {
                    cpu: $.kubernetes.motioneye.resources.requests.cpu,
                    memory: $.kubernetes.motioneye.resources.requests.memory,
                },
                limits: {
                    cpu: $.kubernetes.motioneye.resources.limits.cpu,
                    memory: $.kubernetes.motioneye.resources.limits.memory,
                },
            },
        },
    },
    app: {
        motioneye: {
            imageTag: $.application.motioneye.imageTag,
            ip: $.application.motioneye.ip,
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
