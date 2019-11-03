local piholeComponent = import "../../components/pihole/pihole.libsonnet";

{
    kubernetes:: {
        namespace:: error "namespace is required",
        appNamePrefix:: error "namePrefix is required",
        labels:: error "labels is required",
        pihole:: {
            resources:: piholeComponent.configuration.kube.resources,
        },
    },
    application:: {
        pihole:: {
            imageTag:: error "pihole.imageTag is required",
            ip:: error "pihole.ip is required",
            webPassword:: error "pihole.webPassword is required",
        },
        // persistentData:: {
        //     use:: error "persistentData.use is required",
        //     cheap:: {
        //         nfsServer:: error "persistentData.cheap.nfsServer is required",
        //         nfsRootPath:: error "persistentData.cheap.nfsRootPath is required",
        //     },
        //     expensive:: {
        //         nfsServer:: error "persistentData.expensive.nfsServer is required",
        //         nfsRootPath:: error "persistentData.expensive.nfsRootPath is required",
        //     },
        // },
    },

    kube: {
        namespace: $.kubernetes.namespace,
        name: $.kubernetes.appNamePrefix,
        labels: $.kubernetes.labels,
        pihole: {
            resources: {
                requests: {
                    cpu: $.kubernetes.pihole.resources.requests.cpu,
                    memory: $.kubernetes.pihole.resources.requests.memory,
                },
                limits: {
                    cpu: $.kubernetes.pihole.resources.limits.cpu,
                    memory: $.kubernetes.pihole.resources.limits.memory,
                },
            },
        },
    },
    app: {
        pihole: {
            imageTag: $.application.pihole.imageTag,
            ip: $.application.pihole.ip,
            webPassword: $.application.pihole.webPassword,
        },
        // persistentData: {
        //     use: $.application.persistentData.use,
        // } + (
        //     if $.application.persistentData.use then {
        //         cheap: {
        //             nfsServer: $.application.persistentData.expensive.nfsServer,
        //             nfsRootPath: $.application.persistentData.cheap.nfsRootPath,
        //         },
        //         expensive: {
        //             nfsServer: $.application.persistentData.expensive.nfsServer,
        //             nfsRootPath: $.application.persistentData.expensive.nfsRootPath,
        //         },
        //     } else {}
        // ),
    },
}
