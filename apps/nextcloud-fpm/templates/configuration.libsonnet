{
    kubernetes:: {
        namespace:: error "namespace is required",
        appNamePrefix:: error "namePrefix is required",
        labels:: error "labels is required",
        certificateIssuer:: {
            name:: error "certificateIssuer.name is required",
            kind:: error "certificateIssuer.kind is required",
        },
    },
    application:: {
        nextcloud:: {
            imageTag:: error "nextcloud.imageTag is required",
            adminUser:: error "nextcloud.adminUser is required",
            adminPassword:: error "nextcloud.adminPassword is required",
            domain:: error "nextcloud.domain is required",
            nginx:: {
                imageTag:: error "nextcloud.nginx.imageTag is required",
            },
        },
        mariadb:: {
            use:: error "mariadb.use is required",
            imageTag:: error "mariadb.imageTag is required",
            rootPassword:: error "mariadb.rootPassword is required",
            nextcloudUser:: error "mariadb.nextcloudUser is required",
            nextcloudUserPassword:: error "mariadb.nextcloudUserPassword is required",
            nextcloudDatabase:: error "mariadb.nextcloudDatabase is required",
        },
        redis:: {
            use:: error "redis.use is required",
            imageTag:: error "redis.imageTag is required",
        },
        onlyoffice:: {
            use:: error "onlyoffice.use is required",
            imageTag:: error "onlyoffice.imageTag is required",
            jwtSecret:: error "onlyoffice.jwtSecret is required",
            domain:: error "onlyoffice.domain is required",
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
        certificateIssuer: {
            name: $.kubernetes.certificateIssuer.name,
            kind: $.kubernetes.certificateIssuer.kind,
        },
    },
    app: {
        nextcloud: {
            imageTag: $.application.nextcloud.imageTag,
            adminUser: $.application.nextcloud.adminUser,
            adminPassword: $.application.nextcloud.adminPassword,
            domain: $.application.nextcloud.domain,
            nginx: {
                imageTag: $.application.nextcloud.nginx.imageTag,
            },
        },
        mariadb: {
            use: $.application.mariadb.use,
        } + (
            if $.application.mariadb.use then {
                imageTag: $.application.mariadb.imageTag,
                rootPassword: $.application.mariadb.rootPassword,
                nextcloudUser: $.application.mariadb.nextcloudUser,
                nextcloudUserPassword: $.application.mariadb.nextcloudUserPassword,
                nextcloudDatabase: $.application.mariadb.nextcloudDatabase,
            } else {}
        ),
        redis: {
            use: $.application.redis.use,
        } + (
            if $.application.redis.use then {
                imageTag: $.application.redis.imageTag,
            } else {}
        ),
        onlyoffice: {
            use: $.application.onlyoffice.use,
        } + (
            if $.application.redis.use then {
                imageTag: $.application.onlyoffice.imageTag,
                jwtSecret: $.application.onlyoffice.jwtSecret,
                domain: $.application.onlyoffice.domain,
            } else {}
        ),
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
