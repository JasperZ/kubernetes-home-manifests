{
    kubernetes:: {
        namespace:: error "namespace is required",
        appNamePrefix:: error "namePrefix is required",
        labels:: error "labels is required",
        certificateIssuer:: {
            name:: error "certificateIssuer.name is required",
            kind:: error "certificateIssuer.kind is required",
        },
        homeassistant:: {
            resources:: {
                requests:: {
                    cpu:: "125m",
                    memory:: "128Mi",
                },
                limits:: {
                    cpu:: "500m",
                    memory:: "512Mi",
                },
            },
        },
        nodered:: {
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
        influxdb:: {
            resources:: {
                requests:: {
                    cpu:: "250m",
                    memory:: "128Mi",
                },
                limits:: {
                    cpu:: "500m",
                    memory:: "512Mi",
                },
            },
        },
        mariadb:: {
            resources:: {
                requests:: {
                    cpu:: "125m",
                    memory:: "128Mi",
                },
                limits:: {
                    cpu:: "500m",
                    memory:: "512Mi",
                },
            },
        },
    },
    application:: {
        homeassistant:: {
            imageTag:: error "homeassistant.imageTag is required",
            domain:: error "homeassistant.domain is required",
            curl:: {
                imageTag:: error "homeassistant.curl.imageTag is required",
            },
        },
        nodered:: {
            use:: error "mariadb.use is required",
            imageTag:: error "homeassistant.imageTag is required",
        },
        influxdb:: {
            use:: error "mariadb.use is required",
            imageTag:: error "influxdb.imageTag is required",
            adminUser:: error "influxdb.adminUser is required",
            adminUserPassword:: error "influxdb.adminUserPassword is required",
            writeUser:: error "influxdb.writeUser is required",
            writeUserPassword:: error "influxdb.writeUserPassword is required",
            readUser:: error "influxdb.readUser is required",
            readUserPassword:: error "influxdb.readUserPassword is required",
            database:: error "influxdb.database is required",
        },
        mariadb:: {
            use:: error "mariadb.use is required",
            imageTag:: error "mariadb.imageTag is required",
            rootPassword:: error "mariadb.rootPassword is required",
            homeassistantUser:: error "mariadb.homeassistantUser is required",
            homeassistantUserPassword:: error "mariadb.homeassistantUserPassword is required",
            homeassistantDatabase:: error "mariadb.homeassistantDatabase is required",
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
        homeassistant: {
            resources: {
                requests: {
                    cpu: $.kubernetes.homeassistant.resources.requests.cpu,
                    memory: $.kubernetes.homeassistant.resources.requests.memory,
                },
                limits: {
                    cpu: $.kubernetes.homeassistant.resources.limits.cpu,
                    memory: $.kubernetes.homeassistant.resources.limits.memory,
                },
            },
        },
        [if $.application.nodered.use then "nodered"]: {
            resources: {
                requests: {
                    cpu: $.kubernetes.nodered.resources.requests.cpu,
                    memory: $.kubernetes.nodered.resources.requests.memory,
                },
                limits: {
                    cpu: $.kubernetes.nodered.resources.limits.cpu,
                    memory: $.kubernetes.nodered.resources.limits.memory,
                },
            },
        },
        [if $.application.influxdb.use then "influxdb"]: {
            resources: {
                requests: {
                    cpu: $.kubernetes.influxdb.resources.requests.cpu,
                    memory: $.kubernetes.influxdb.resources.requests.memory,
                },
                limits: {
                    cpu: $.kubernetes.influxdb.resources.limits.cpu,
                    memory: $.kubernetes.influxdb.resources.limits.memory,
                },
            },
        },
        [if $.application.mariadb.use then "mariadb"]: {
            resources: {
                requests: {
                    cpu: $.kubernetes.mariadb.resources.requests.cpu,
                    memory: $.kubernetes.mariadb.resources.requests.memory,
                },
                limits: {
                    cpu: $.kubernetes.mariadb.resources.limits.cpu,
                    memory: $.kubernetes.mariadb.resources.limits.memory,
                },
            },
        },
    },
    app: {
        homeassistant: {
            imageTag: $.application.homeassistant.imageTag,
            domain: $.application.homeassistant.domain,
            curl: {
                imageTag: $.application.homeassistant.curl.imageTag,
            },
        },
        nodered: {
            use: $.application.nodered.use,
        } + (
            if $.application.nodered.use then {
                imageTag: $.application.nodered.imageTag,
                ip: $.application.nodered.ip,
            } else {}
        ),
        influxdb: {
            use: $.application.influxdb.use,
        } + (
            if $.application.influxdb.use then {
                imageTag: $.application.influxdb.imageTag,
                adminUser: $.application.influxdb.adminUser,
                adminUserPassword: $.application.influxdb.adminUserPassword,
                writeUser: $.application.influxdb.writeUser,
                writeUserPassword: $.application.influxdb.writeUserPassword,
                readUser: $.application.influxdb.readUser,
                readUserPassword: $.application.influxdb.readUserPassword,
                database: $.application.influxdb.database,
            } else {}
        ),
        mariadb: {
            use: $.application.mariadb.use,
        } + (
            if $.application.mariadb.use then {
                imageTag: $.application.mariadb.imageTag,
                rootPassword: $.application.mariadb.rootPassword,
                homeassistantUser: $.application.mariadb.homeassistantUser,
                homeassistantUserPassword: $.application.mariadb.homeassistantUserPassword,
                homeassistantDatabase: $.application.mariadb.homeassistantDatabase,
            } else {}
        ),
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
