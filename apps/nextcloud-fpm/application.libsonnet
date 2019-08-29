local kube = import "../../templates/kubernetes.libsonnet";
local mariadbComponent = import "../../components/mariadb/mariadb.libsonnet";
local redisComponent = import "../../components/redis/redis.libsonnet";
local onlyofficeComponent = import "../../components/onlyoffice/onlyoffice.libsonnet";
local nextcloudComponent = import "../../components/nextcloud/nextcloud.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

    // MariaDB Component
    local mariadbConfig = mariadbComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.mariadb.imageTag,
            resources:: conf.kube.mariadb.resources,
        },
        app+:: {
            rootPassword:: conf.app.mariadb.rootPassword,
            user:: conf.app.mariadb.nextcloudUser,
            userPassword:: conf.app.mariadb.nextcloudUserPassword,
            database:: conf.app.mariadb.nextcloudDatabase,
        },
        data+:: {
            persist:: conf.app.persistentData.use,
            nfsVolumes+:: {
                data+:: {
                    nfsServer:: conf.app.persistentData.expensive.nfsServer,
                    nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/mariadb/data",
                },
            },
        },
    },
    local mariadb = mariadbComponent.new(namespace, name, labels, mariadbConfig),

    // Redis Component
    local redisConfig = redisComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.redis.imageTag,
            resources:: conf.kube.redis.resources,
        },
        data+:: {
            persist:: conf.app.persistentData.use,
            nfsVolumes+:: {
                data+:: {
                    nfsServer:: conf.app.persistentData.expensive.nfsServer,
                    nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/redis/data",
                },
            },
        },
    },
    local redis = redisComponent.new(namespace, name, labels, redisConfig),

    // Onlyoffice Component
    local onlyofficeConfig = onlyofficeComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.onlyoffice.imageTag,
            resources:: conf.kube.onlyoffice.resources,
            certificateIssuer+:: {
                name:: conf.kube.certificateIssuer.name,
                kind:: conf.kube.certificateIssuer.kind,
            },
        },
        app+:: {
            jwtSecret:: conf.app.onlyoffice.jwtSecret,
            domain:: conf.app.onlyoffice.domain,
        },
    },
    local onlyoffice = onlyofficeComponent.new(namespace, name, labels, onlyofficeConfig),

    // Nextcloud Component
    local nextcloudConfig = nextcloudComponent.configuration + {
        kube+:: {
            nextcloud+:: {
                imageTag:: conf.app.nextcloud.imageTag,
                resources:: conf.kube.nextcloud.resources,
            },
            nginx+:: {
                imageTag:: conf.app.nextcloud.nginx.imageTag,
                resources:: conf.kube.nextcloud.nginx.resources,
            },
            certificateIssuer+:: {
                name:: conf.kube.certificateIssuer.name,
                kind:: conf.kube.certificateIssuer.kind,
            },
        },
        app+:: {
            adminUser:: conf.app.nextcloud.adminUser,
            adminPassword:: conf.app.nextcloud.adminPassword,
            domain:: conf.app.nextcloud.domain,
        },
        data:: {
            persist:: conf.app.persistentData.use,
            nfsVolumes:: {
                html:: {
                    nfsServer:: conf.app.persistentData.expensive.nfsServer,
                    nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/nextcloud/html",
                },
                customApps:: {
                    nfsServer:: conf.app.persistentData.expensive.nfsServer,
                    nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/nextcloud/custom-apps",
                },
                config:: {
                    nfsServer:: conf.app.persistentData.expensive.nfsServer,
                    nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/nextcloud/config",
                },
                data:: {
                    nfsServer:: conf.app.persistentData.cheap.nfsServer,
                    nfsPath:: conf.app.persistentData.cheap.nfsRootPath + "/nextcloud/data",
                },
            },
        },
    },
    local nextcloud = nextcloudComponent.new(
        namespace,
        name,
        labels,
        nextcloudConfig,
        mariadbComponent = (
            if conf.app.mariadb.use then (
                mariadb
            )
        ),
        redisComponent = (
            if conf.app.redis.use then (
                redis
            )
        ),
    ),

    apiVersion: "v1",
    kind: "List",
    items: [
        nextcloud.secret,
        nextcloud.nginxConfigMap,
        nextcloud.service,
        nextcloud.deployment,
        nextcloud.certificate,
        nextcloud.ingress,
    ] + (
        if conf.app.persistentData.use then [
            nextcloud.persistentVolumes[x] for x in std.objectFields(nextcloud.persistentVolumes)
        ] + [
            nextcloud.persistentVolumeClaims[x] for x in std.objectFields(nextcloud.persistentVolumeClaims)  
        ] + [
            nextcloud.cronJob,
        ] else []
    ) + (
        if conf.app.mariadb.use then [
            mariadb.secret,
            mariadb.service,
            mariadb.deployment,
        ] + (
            if conf.app.persistentData.use then [
                mariadb.persistentVolumes[x] for x in std.objectFields(mariadb.persistentVolumes)
            ] + [
                mariadb.persistentVolumeClaims[x] for x in std.objectFields(mariadb.persistentVolumeClaims)  
            ] else []
        ) else []
    ) + (
        if conf.app.redis.use then [
            redis.service,
            redis.deployment,
        ] + (
            if conf.app.persistentData.use then [
                redis.persistentVolumes[x] for x in std.objectFields(redis.persistentVolumes)
            ] + [
                redis.persistentVolumeClaims[x] for x in std.objectFields(redis.persistentVolumeClaims)  
            ] else []
        ) else []
    ) + (
        if conf.app.onlyoffice.use then [
            onlyoffice.secret,
            onlyoffice.service,
            onlyoffice.deployment,
            onlyoffice.certificate,
            onlyoffice.ingress,
        ] else []
    ),
};

{
    new:: new,
}