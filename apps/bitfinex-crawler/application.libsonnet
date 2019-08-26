local kube = import "../../templates/kubernetes.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

    // Secret used by all components
    local secret = kube.secret(
        namespace, 
        name,
        labels,
        stringData = {
            INFLUXDB_DB: conf.app.influxdb.database,
            INFLUXDB_ADMIN_USER: conf.app.influxdb.adminUser,
            INFLUXDB_ADMIN_PASSWORD: conf.app.influxdb.adminUserPassword,
            INFLUXDB_WRITE_USER: conf.app.influxdb.writeUser,
            INFLUXDB_WRITE_USER_PASSWORD: conf.app.influxdb.writeUserPassword,
            INFLUXDB_READ_USER: conf.app.influxdb.readUser,
            INFLUXDB_READ_USER_PASSWORD: conf.app.influxdb.readUserPassword,
        },
    ),

    // influxdb Component
    local influxdbComponentName = "influxdb",
    local influxdbDataDir = "data",

    // influxdb PersistentVolumes
    local influxdbPersistentVolumes = {
        data: kube.persistentVolume(
            name + "-" + influxdbComponentName + "-" + influxdbDataDir,
            labels + {component: influxdbComponentName},
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + influxdbComponentName + "/" + influxdbDataDir,
        ),
    },

    // influxdb PersistentVolumeClaims
    local influxdbPersistentVolumeClaims = {
        data: kube.persistentVolumeClaim(
            namespace,
            influxdbPersistentVolumes.data.metadata.name,
            labels + {component: influxdbComponentName},
            influxdbPersistentVolumes.data.metadata.name,
        ),
    },
    
    // influxdb Deployment
    local influxdbDeployment = kube.deployment(
        namespace,
        name + "-" + influxdbComponentName,
        labels + {component: influxdbComponentName},
        [
            kube.deploymentContainer(
                influxdbComponentName,
                "influxdb",
                conf.app.influxdb.imageTag,
                env = [
                    kube.containerEnvFromValue("INFLUXDB_HTTP_AUTH_ENABLED", "true"),
                    kube.containerEnvFromValue("INFLUXDB_HOST", influxdbService.metadata.name),

                    kube.containerEnvFromSecret("INFLUXDB_DB", secret.metadata.name, "INFLUXDB_DB"),
                    kube.containerEnvFromSecret("INFLUXDB_ADMIN_USER", secret.metadata.name, "INFLUXDB_ADMIN_USER"),
                    kube.containerEnvFromSecret("INFLUXDB_ADMIN_PASSWORD", secret.metadata.name, "INFLUXDB_ADMIN_PASSWORD"),
                    kube.containerEnvFromSecret("INFLUXDB_WRITE_USER", secret.metadata.name, "INFLUXDB_WRITE_USER"),
                    kube.containerEnvFromSecret("INFLUXDB_WRITE_USER_PASSWORD", secret.metadata.name, "INFLUXDB_WRITE_USER_PASSWORD"),
                    kube.containerEnvFromSecret("INFLUXDB_READ_USER", secret.metadata.name, "INFLUXDB_READ_USER"),
                    kube.containerEnvFromSecret("INFLUXDB_READ_USER_PASSWORD", secret.metadata.name, "INFLUXDB_READ_USER_PASSWORD"),
                ],
                ports = [
                    kube.containerPort(8086),
                ],
                volumeMounts = (
                    if conf.app.persistentData.use then [
                        kube.containerVolumeMount(influxdbDataDir, "/var/lib/influxdb"),
                    ] else []
                ),
                resources = conf.kube.influxdb.resources,
            ),
        ],
        volumes = (
            if conf.app.persistentData.use then [
                kube.deploymentVolumePVC(influxdbDataDir, influxdbPersistentVolumeClaims.data.metadata.name),
            ] else []
        ),
    ),

    // influxdb Service
    local influxdbService = kube.service(
        namespace,
        name + "-" + influxdbComponentName,
        labels + {component: influxdbComponentName},
        influxdbDeployment.metadata.labels,
        [
            kube.servicePort("http", "TCP", 8086, 8086),
        ],
    ),

    // crawler Component
    local crawlerComponentName = "bitfinex-crawler",
    local crawlerDataDir = "data",

    // crawler PersistentVolumes
    local crawlerPersistentVolumes = {
        data: kube.persistentVolume(
            name + "-" + crawlerComponentName + "-" + crawlerDataDir,
            labels + {component: crawlerComponentName},
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + crawlerComponentName + "/" + crawlerDataDir,
        ),
    },

    // crawler PersistentVolumeClaims
    local crawlerPersistentVolumeClaims = {
        data: kube.persistentVolumeClaim(
            namespace,
            crawlerPersistentVolumes.data.metadata.name,
            labels + {component: crawlerComponentName},
            crawlerPersistentVolumes.data.metadata.name,
        ),
    },

    // crawler Deployment
    local crawlerDeployment = kube.deployment(
        namespace,
        name + "-" + crawlerComponentName,
        labels + {component: crawlerComponentName},
        [
            kube.deploymentContainer(
                crawlerComponentName,
                "zdock/bitfinex-crawler",
                conf.app.crawler.imageTag,
                env = [
                    kube.containerEnvFromValue("TICKER_SYMBOLS", conf.app.crawler.tradingSymbols),
                    kube.containerEnvFromValue("INFLUXDB_HOST", influxdbService.metadata.name),
                    kube.containerEnvFromSecret("INFLUXDB_DATABASE", secret.metadata.name, "INFLUXDB_DB"),
                    kube.containerEnvFromSecret("INFLUXDB_USERNAME", secret.metadata.name, "INFLUXDB_WRITE_USER"),
                    kube.containerEnvFromSecret("INFLUXDB_PASSWORD", secret.metadata.name, "INFLUXDB_WRITE_USER_PASSWORD"),
                ],
                resources = conf.kube.crawler.resources,
            ),
        ],
        initContainers = [
            kube.deploymentContainer(
                "init-influxdb",
                "appropriate/curl",
                conf.app.crawler.curl.imageTag,
                command = [
                    "sh",
                    "-c",
                    "until curl -sL -I %(service)s:8086/ping; do echo waiting for %(service)s; sleep 2; done;" % {service: influxdbService.metadata.name},
                ],
            ),
        ],
    ),

    apiVersion: "v1",
    kind: "List",
    items: [
        secret,
        crawlerDeployment,
        influxdbService,
        influxdbDeployment
    ] + (
        if conf.app.persistentData.use then [
            influxdbPersistentVolumes[x] for x in std.objectFields(influxdbPersistentVolumes)
        ] + [
            influxdbPersistentVolumeClaims[x] for x in std.objectFields(influxdbPersistentVolumeClaims)  
        ] else []
    ),
};

{
    new:: new,
}