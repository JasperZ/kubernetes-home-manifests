local dokuwikiComponent = import "../../components/dokuwiki/dokuwiki.libsonnet";

{
    kubernetes:: {
        namespace:: error "namespace is required",
        appNamePrefix:: error "namePrefix is required",
        labels:: error "labels is required",
        dokuwiki:: {
            resources:: dokuwikiComponent.configuration.kube.resources,
        },
    },
    application:: {
        dokuwiki:: {
            imageTag:: error "dokuwiki.imageTag is required",
            adminUsername:: error "dokuwiki.adminUsername is required",
            adminPassword:: error "dokuwiki.adminPassword is required",
            adminFullName:: error "dokuwiki.adminFullName is required",
            adminEmail:: error "dokuwiki.adminEmail is required",
            wikiName:: error "dokuwiki.wikiName is required",
            ip:: error "dokuwiki.ip is required",
        },
        persistentData:: {
            use:: error "persistentData.use is required",
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
        certificateIssuer: {
            name: $.kubernetes.certificateIssuer.name,
            kind: $.kubernetes.certificateIssuer.kind,
        },
        dokuwiki: {
            resources: {
                requests: {
                    cpu: $.kubernetes.dokuwiki.resources.requests.cpu,
                    memory: $.kubernetes.dokuwiki.resources.requests.memory,
                },
                limits: {
                    cpu: $.kubernetes.dokuwiki.resources.limits.cpu,
                    memory: $.kubernetes.dokuwiki.resources.limits.memory,
                },
            },
        },
    },
    app: {
        dokuwiki: {
            imageTag: $.application.dokuwiki.imageTag,
            adminUsername: $.application.dokuwiki.adminUsername,
            adminPassword: $.application.dokuwiki.adminPassword,
            adminFullName: $.application.dokuwiki.adminFullName,
            adminEmail: $.application.dokuwiki.adminEmail,
            wikiName: $.application.dokuwiki.wikiName,
            ip: $.application.dokuwiki.ip,
        },
        persistentData: {
            use: $.application.persistentData.use,
        } + (
            if $.application.persistentData.use then {
                expensive: {
                    nfsServer: $.application.persistentData.expensive.nfsServer,
                    nfsRootPath: $.application.persistentData.expensive.nfsRootPath,
                },
            } else {}
        ),
    },
}
