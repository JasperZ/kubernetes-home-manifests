local bitwardenComponent = import "../../components/bitwarden/bitwarden.libsonnet";

{
    kubernetes:: {
        namespace:: error "namespace is required",
        appNamePrefix:: error "namePrefix is required",
        labels:: error "labels is required",
        certificateIssuer:: {
            name:: error "certificateIssuer.name is required",
            kind:: error "certificateIssuer.kind is required",
        },
        bitwarden:: {
            resources:: bitwardenComponent.configuration.kube.resources,
        },
    },
    application:: {
        bitwarden:: {
            imageTag:: error "bitwarden.imageTag is required",
            adminToken:: error "bitwarden.adminToken is required",
            signupsAllowed:: error "bitwarden.signupsAllowed is required",
            domain:: error "bitwarden.domain is required",
            smtp:: {
                use:: error "bitwarden.smtp.use is required",
                host:: error "bitwarden.smtp.host is required",
                from:: error "bitwarden.smtp.from is required",
                port:: error "bitwarden.smtp.port is required",
                ssl:: error "bitwarden.smtp.ssl is required",
                username:: error "bitwarden.smtp.username is required",
                password:: error "bitwarden.smtp.password is required",
            },
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
        bitwarden: {
            resources: {
                requests: {
                    cpu: $.kubernetes.bitwarden.resources.requests.cpu,
                    memory: $.kubernetes.bitwarden.resources.requests.memory,
                },
                limits: {
                    cpu: $.kubernetes.bitwarden.resources.limits.cpu,
                    memory: $.kubernetes.bitwarden.resources.limits.memory,
                },
            },
        },
    },
    app: {
        bitwarden: {
            imageTag: $.application.bitwarden.imageTag,
            adminToken: $.application.bitwarden.adminToken,
            signupsAllowed: $.application.bitwarden.signupsAllowed,
            domain: $.application.bitwarden.domain,
            smtp: {
                use: $.application.bitwarden.smtp.use,
            } + (
                if $.application.bitwarden.smtp.use then {
                    host: $.application.bitwarden.smtp.host,
                    from: $.application.bitwarden.smtp.from,
                    port: $.application.bitwarden.smtp.port,
                    ssl: $.application.bitwarden.smtp.ssl,
                    username: $.application.bitwarden.smtp.username,
                    password: $.application.bitwarden.smtp.password,
                } else {}
            ),
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
