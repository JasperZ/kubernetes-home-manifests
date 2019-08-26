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
        stringData = (
            if conf.app.influxdb.use then {
                INFLUXDB_DB: conf.app.influxdb.database,
                INFLUXDB_ADMIN_USER: conf.app.influxdb.adminUser,
                INFLUXDB_ADMIN_PASSWORD: conf.app.influxdb.adminUserPassword,
                INFLUXDB_WRITE_USER: conf.app.influxdb.writeUser,
                INFLUXDB_WRITE_USER_PASSWORD: conf.app.influxdb.writeUserPassword,
                INFLUXDB_READ_USER: conf.app.influxdb.readUser,
                INFLUXDB_READ_USER_PASSWORD: conf.app.influxdb.readUserPassword,
            } else {}
        ) + (
            if conf.app.mariadb.use then {
                MYSQL_ROOT_PASSWORD: conf.app.mariadb.rootPassword,
                MYSQL_DATABASE: conf.app.mariadb.homeassistantDatabase,
                MYSQL_USER: conf.app.mariadb.homeassistantUser,
                MYSQL_PASSWORD: conf.app.mariadb.homeassistantUserPassword,
            } else {}
        ),
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

    // mariadb Component
    local mariadbComponentName = "mariadb",
    local mariadbDataDir = "data",

    // mariadb PersistentVolumes
    local mariadbPersistentVolumes = {
        data: kube.persistentVolume(
            name + "-" + mariadbComponentName + "-" + mariadbDataDir,
            labels + {component: mariadbComponentName},
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + mariadbComponentName + "/" + mariadbDataDir,
        ),
    },

    // mariadb PersistentVolumeClaims
    local mariadbPersistentVolumeClaims = {
        data: kube.persistentVolumeClaim(
            namespace,
            mariadbPersistentVolumes.data.metadata.name,
            labels + {component: mariadbComponentName},
            mariadbPersistentVolumes.data.metadata.name,
        ),
    },

    // mariadb Deployment
    local mariadbDeployment = kube.deployment(
        namespace,
        name + "-" + mariadbComponentName,
        labels + {component: mariadbComponentName},
        [
            kube.deploymentContainer(
                mariadbComponentName,
                "mariadb",
                conf.app.mariadb.imageTag,
                env = [
                    kube.containerEnvFromSecret("MYSQL_ROOT_PASSWORD", secret.metadata.name, "MYSQL_ROOT_PASSWORD"),
                    kube.containerEnvFromSecret("MYSQL_USER", secret.metadata.name, "MYSQL_USER"),
                    kube.containerEnvFromSecret("MYSQL_PASSWORD", secret.metadata.name, "MYSQL_PASSWORD"),
                    kube.containerEnvFromSecret("MYSQL_DATABASE", secret.metadata.name, "MYSQL_DATABASE"),
                ],
                ports = [
                    kube.containerPort(3306),
                ],
                volumeMounts = (
                    if conf.app.persistentData.use then [
                        kube.containerVolumeMount(mariadbDataDir, "/var/lib/mysql"),
                    ] else []
                ),
                resources = conf.kube.mariadb.resources,
            ),
        ],
        volumes = (
            if conf.app.persistentData.use then [
                kube.deploymentVolumePVC(mariadbDataDir, mariadbPersistentVolumeClaims.data.metadata.name),
            ] else []
        ),
    ),

    // mariadb Service
    local mariadbService = kube.service(
        namespace,
        name + "-" + mariadbComponentName,
        labels + {component: mariadbComponentName},
        mariadbDeployment.metadata.labels,
        [
            kube.servicePort("mysql", "TCP", 3306, 3306),
        ],
    ),

    // nodered Component
    local noderedComponentName = "nodered",
    local noderedDataDir = "data",

    // nodered PersistentVolumes
    local noderedPersistentVolumes = {
        data: kube.persistentVolume(
            name + "-" + noderedComponentName + "-" + noderedDataDir,
            labels + {component: noderedComponentName},
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + noderedComponentName + "/" + noderedDataDir,
        ),
    },

    // nodered PersistentVolumeClaims
    local noderedPersistentVolumeClaims = {
        data: kube.persistentVolumeClaim(
            namespace,
            noderedPersistentVolumes.data.metadata.name,
            labels + {component: noderedComponentName},
            noderedPersistentVolumes.data.metadata.name,
        ),
    },
    
    // nodered Deployment
    local noderedDeployment = kube.deployment(
        namespace,
        name + "-" + noderedComponentName,
        labels + {component: noderedComponentName},
        [
            kube.deploymentContainer(
                noderedComponentName,
                "nodered/node-red-docker",
                conf.app.nodered.imageTag,
                ports = [
                    kube.containerPort(1880),
                ],
                volumeMounts = (
                    if conf.app.persistentData.use then [
                        kube.containerVolumeMount(noderedDataDir, "/data"),
                    ] else []
                ),
                resources = conf.kube.nodered.resources,
            ),
        ],
        volumes = (
            if conf.app.persistentData.use then [
                kube.deploymentVolumePVC(noderedDataDir, noderedPersistentVolumeClaims.data.metadata.name),
            ] else []
        ),
    ),

    // nodered Service
    local noderedService = kube.service(
        namespace,
        name + "-" + noderedComponentName,
        labels + {component: noderedComponentName},
        noderedDeployment.metadata.labels,
        [
            kube.servicePort("http", "TCP", 80, 1880),
        ],
    ) + {
        spec+: {
            type: "LoadBalancer", 
            loadBalancerIP: conf.app.nodered.ip,
            externalTrafficPolicy: "Local",
        },
    },

    // homeassistant Component
    local homeassistantComponentName = "homeassistant",
    local homeassistantConfigDir = "config",

    // homeassistant PersistentVolumes
    local homeassistantPersistentVolumes = {
        data: kube.persistentVolume(
            name + "-" + homeassistantComponentName + "-" + homeassistantConfigDir,
            labels + {component: homeassistantComponentName},
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + homeassistantComponentName + "/" + homeassistantConfigDir,
        ),
    },

    // homeassistant PersistentVolumeClaims
    local homeassistantPersistentVolumeClaims = {
        data: kube.persistentVolumeClaim(
            namespace,
            homeassistantPersistentVolumes.data.metadata.name,
            labels + {component: homeassistantComponentName},
            homeassistantPersistentVolumes.data.metadata.name,
        ),
    },
    
    // homeassistant Deployment
    local homeassistantDeployment = kube.deployment(
        namespace,
        name + "-" + homeassistantComponentName,
        labels + {component: homeassistantComponentName},
        [
            kube.deploymentContainer(
                homeassistantComponentName,
                "homeassistant/home-assistant",
                conf.app.homeassistant.imageTag,
                ports = [
                    kube.containerPort(8123),
                ],
                volumeMounts = (
                    if conf.app.persistentData.use then [
                        kube.containerVolumeMount(homeassistantConfigDir, "/config"),
                    ] else []
                ),
                resources = conf.kube.homeassistant.resources,
            ),
        ],
        initContainers = (
            if conf.app.influxdb.use then [
                    kube.deploymentContainer(
                    "init-influxdb",
                    "appropriate/curl",
                    conf.app.homeassistant.curl.imageTag,
                    command = [
                        "sh",
                        "-c",
                        "until curl -sL -I %(service)s:8086/ping; do echo waiting for %(service)s; sleep 2; done;" % {service: influxdbService.metadata.name},
                    ],
                ),
            ] else []
        ) + (
            if conf.app.mariadb.use then [
                kube.deploymentContainer(
                    "init-mariadb",
                    "mariadb",
                    conf.app.mariadb.imageTag,
                    command = [
                        "sh",
                        "-c",
                        "until mysql -h %(service)s -u $MYSQL_USER --password=$MYSQL_PASSWORD -e 'SELECT 1'; do echo waiting for %(service)s; sleep 2; done;" % {service: mariadbService.metadata.name},
                    ],
                    env = [
                        kube.containerEnvFromSecret("MYSQL_USER", secret.metadata.name, "MYSQL_USER"),
                        kube.containerEnvFromSecret("MYSQL_PASSWORD", secret.metadata.name, "MYSQL_PASSWORD"),
                    ],
                    ports = [
                        kube.containerPort(3306),
                    ],
                ),
            ] else []
        ),
        volumes = (
            if conf.app.persistentData.use then [
                kube.deploymentVolumePVC(homeassistantConfigDir, homeassistantPersistentVolumeClaims.data.metadata.name),
            ] else []
        ),
    ),

    // homeassistant Service
    local homeassistantService = kube.service(
        namespace,
        name + "-" + homeassistantComponentName,
        labels + {component: homeassistantComponentName},
        homeassistantDeployment.metadata.labels,
        [
            kube.servicePort("http", "TCP", 80, 8123),
        ],
    ),

    // homeassistant Certificate
    local homeassistantCertificate = kube.certificate(
        namespace,
        name + "-" + homeassistantComponentName,
        labels + {component: homeassistantComponentName},
        "%(domain)s-tls" % {domain: std.strReplace(conf.app.homeassistant.domain, ".", "-")},
        conf.app.homeassistant.domain,
        {metadata: conf.kube.certificateIssuer},
    ),

    // homeassistant Ingress
    local homeassistantIngress = kube.ingress(
        namespace,
        name + "-" + homeassistantComponentName,
        labels + {component: homeassistantComponentName},
        tls = [
            kube.ingressTls(
                [conf.app.homeassistant.domain],
                "%(domain)s-tls" % {domain: std.strReplace(conf.app.homeassistant.domain, ".", "-")}
            ),
        ],
        rules = [
            kube.ingressRule(
                conf.app.homeassistant.domain,
                [
                    kube.ingressRulePath(homeassistantService.metadata.name, 80),
                ],
            ),
        ],
    ),

    apiVersion: "v1",
    kind: "List",
    items: [
        secret,
        homeassistantService,
        homeassistantDeployment,
        homeassistantCertificate,
        homeassistantIngress,
    ] + (
        if conf.app.persistentData.use then [
            homeassistantPersistentVolumes[x] for x in std.objectFields(homeassistantPersistentVolumes)
        ] + [
            homeassistantPersistentVolumeClaims[x] for x in std.objectFields(homeassistantPersistentVolumeClaims)  
        ] else []
    ) + (
        if conf.app.influxdb.use then [
            influxdbService,
            influxdbDeployment,
        ] + (
            if conf.app.persistentData.use then [
                influxdbPersistentVolumes[x] for x in std.objectFields(influxdbPersistentVolumes)
            ] + [
                influxdbPersistentVolumeClaims[x] for x in std.objectFields(influxdbPersistentVolumeClaims)  
            ] else []
        ) else []
    ) + (
        if conf.app.mariadb.use then [
            mariadbService,
            mariadbDeployment,
        ] + (
            if conf.app.persistentData.use then [
                mariadbPersistentVolumes[x] for x in std.objectFields(mariadbPersistentVolumes)
            ] + [
                mariadbPersistentVolumeClaims[x] for x in std.objectFields(mariadbPersistentVolumeClaims)  
            ] else []
        ) else []
    ) + (
        if conf.app.nodered.use then [
            noderedService,
            noderedDeployment,
        ] + (
            if conf.app.persistentData.use then [
                noderedPersistentVolumes[x] for x in std.objectFields(noderedPersistentVolumes)
            ] + [
                noderedPersistentVolumeClaims[x] for x in std.objectFields(noderedPersistentVolumeClaims)  
            ] else []
        ) else []
    ),
};

{
    new:: new,
}