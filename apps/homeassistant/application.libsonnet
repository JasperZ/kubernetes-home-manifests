local kube = import "../../templates/kubernetes.libsonnet";
local influxdbComponent = import "../../components/influxdb.libsonnet";
local mariadbComponent = import "../../components/mariadb.libsonnet";
local noderedComponent = import "../../components/nodered.libsonnet";

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
    local influxdbConfig = influxdbComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.influxdb.imageTag,
            resources:: conf.kube.influxdb.resources,
        },
        app+:: {
            adminUser:: conf.app.influxdb.adminUser,
            adminUserPassword:: conf.app.influxdb.adminUserPassword,
            writeUser:: conf.app.influxdb.writeUser,
            writeUserPassword:: conf.app.influxdb.writeUserPassword,
            readUser:: conf.app.influxdb.readUser,
            readUserPassword:: conf.app.influxdb.readUserPassword,
            database:: conf.app.influxdb.database,
        },
        data+:: {
            persist:: conf.app.persistentData.use,
            nfsVolumes+:: {
                data+:: {
                    nfsServer:: conf.app.persistentData.expensive.nfsServer,
                    nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/influxdb/data",
                },
            },
        },
    },
    local influxdb = influxdbComponent.new(namespace, name, labels, 8086, influxdbConfig),

    // mariadb Component
    local mariadbConfig = mariadbComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.mariadb.imageTag,
            resources:: conf.kube.mariadb.resources,
        },
        app+:: {
            rootPassword:: conf.app.mariadb.rootPassword,
            user:: conf.app.mariadb.homeassistantUser,
            userPassword:: conf.app.mariadb.homeassistantUserPassword,
            database:: conf.app.mariadb.homeassistantDatabase,
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
    local mariadb = mariadbComponent.new(namespace, name, labels, 3306, mariadbConfig),

    // nodered Component
    local noderedConfig = noderedComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.nodered.imageTag,
            resources:: conf.kube.nodered.resources,
        },
        app+:: {
            timezone:: "Europe/Berlin",
            ip:: conf.app.nodered.ip,
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
    local nodered = noderedComponent.new(namespace, name, labels, 80, noderedConfig),

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
                        "until curl -sL -I %(service)s:8086/ping; do echo waiting for %(service)s; sleep 2; done;" % {service: influxdb.service.metadata.name},
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
                        "until mysql -h %(service)s -u $MYSQL_USER --password=$MYSQL_PASSWORD -e 'SELECT 1'; do echo waiting for %(service)s; sleep 2; done;" % {service: mariadb.service.metadata.name},
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
            influxdb.service,
            influxdb.deployment,
        ] + (
            if conf.app.persistentData.use then [
                influxdb.persistentVolumes[x] for x in std.objectFields(influxdb.persistentVolumes)
            ] + [
                influxdb.persistentVolumeClaims[x] for x in std.objectFields(influxdb.persistentVolumeClaims)  
            ] else []
        ) else []
    ) + (
        if conf.app.mariadb.use then [
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
        if conf.app.nodered.use then [
            nodered.service,
            nodered.deployment,
        ] + (
            if conf.app.persistentData.use then [
                nodered.persistentVolumes[x] for x in std.objectFields(nodered.persistentVolumes)
            ] + [
                nodered.persistentVolumeClaims[x] for x in std.objectFields(nodered.persistentVolumeClaims)  
            ] else []
        ) else []
    ),
};

{
    new:: new,
}