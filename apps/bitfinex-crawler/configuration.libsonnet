local crawlerComponent = import "../../components/crawler.libsonnet";
local influxdbComponent = import "../../components/influxdb.libsonnet";

{
    kubernetes:: {
        namespace:: error "namespace is required",
        appNamePrefix:: error "namePrefix is required",
        labels:: error "labels is required",
        crawler:: {
            resources:: crawlerComponent.configuration.kube.resources,
            curl:: {
                resources:: {
                    requests:: {
                        cpu:: "50m",
                        memory:: "32Mi",
                    },
                    limits:: {
                        cpu:: "100m",
                        memory:: "64Mi",
                    },
                },
            },
        },
        influxdb:: {
            resources:: influxdbComponent.configuration.kube.resources,
        },
    },
    application:: {
        crawler:: {
            imageTag:: error "crawler.imageTag is required",
            tradingSymbols:: error "crawler.tradingSymbols is required",
            curl:: {
                imageTag:: error "crawler.curl.imageTag is required",
            },
        },
        influxdb:: {
            imageTag:: error "influxdb.imageTag is required",
            adminUser:: error "influxdb.adminUser is required",
            adminUserPassword:: error "influxdb.adminUserPassword is required",
            writeUser:: error "influxdb.writeUser is required",
            writeUserPassword:: error "influxdb.writeUserPassword is required",
            readUser:: error "influxdb.readUser is required",
            readUserPassword:: error "influxdb.readUserPassword is required",
            database:: error "influxdb.database is required",
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
        crawler: {
            resources: {
                requests: {
                    cpu: $.kubernetes.crawler.resources.requests.cpu,
                    memory: $.kubernetes.crawler.resources.requests.memory,
                },
                limits: {
                    cpu: $.kubernetes.crawler.resources.limits.cpu,
                    memory: $.kubernetes.crawler.resources.limits.memory,
                },
            },
            curl: {
                resources: {
                    requests: {
                        cpu: $.kubernetes.crawler.curl.resources.requests.cpu,
                        memory: $.kubernetes.crawler.curl.resources.requests.memory,
                    },
                    limits: {
                        cpu: $.kubernetes.crawler.curl.resources.limits.cpu,
                        memory: $.kubernetes.crawler.curl.resources.limits.memory,
                    },
                },
            },
        },
        influxdb: {
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
    },
    app: {
        crawler: {
            imageTag: $.application.crawler.imageTag,
            tradingSymbols: $.application.crawler.tradingSymbols,
            curl: {
                imageTag: $.application.crawler.curl.imageTag,
            },
        },
        influxdb: {
            imageTag: $.application.influxdb.imageTag,
            adminUser: $.application.influxdb.adminUser,
            adminUserPassword: $.application.influxdb.adminUserPassword,
            writeUser: $.application.influxdb.writeUser,
            writeUserPassword: $.application.influxdb.writeUserPassword,
            readUser: $.application.influxdb.readUser,
            readUserPassword: $.application.influxdb.readUserPassword,
            database: $.application.influxdb.database,
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
