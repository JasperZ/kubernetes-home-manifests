local kube = import "../../templates/kubernetes.libsonnet";
local influxdbComponent = import "../../components/influxdb.libsonnet";
local mariadbComponent = import "../../components/mariadb.libsonnet";
local noderedComponent = import "../../components/nodered.libsonnet";
local homeassistantComponent = import "../../components/homeassistant.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

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
    local influxdb = influxdbComponent.new(namespace, name, labels, influxdbConfig),

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
    local mariadb = mariadbComponent.new(namespace, name, labels, mariadbConfig),

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
                    nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/nodered/data",
                },
            },
        },
    },
    local nodered = noderedComponent.new(namespace, name, labels, noderedConfig),

    // homeassistant Component
    local homeassistantConfig = homeassistantComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.homeassistant.imageTag,
            resources:: conf.kube.homeassistant.resources,
            certificateIssuer:: conf.kube.certificateIssuer,
        },
        app+:: {
            domain:: conf.app.homeassistant.domain,
        },
        data+:: {
            persist:: conf.app.persistentData.use,
            nfsVolumes+:: {
                config+:: {
                    nfsServer:: conf.app.persistentData.expensive.nfsServer,
                    nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/homeassistant/config",
                },
            },
        },
    },
    local homeassistant = homeassistantComponent.new(
        namespace,
        name,
        labels,
        homeassistantConfig,
        influxdbComponent = (
            if conf.app.influxdb.use then (
                influxdb
            )
        ),
        mariadbComponent = (
            if conf.app.mariadb.use then (
                mariadb
            )
        ),
    ),

    apiVersion: "v1",
    kind: "List",
    items: [
        homeassistant.service,
        homeassistant.deployment,
        homeassistant.certificate,
        homeassistant.ingress,
    ] + (
        if conf.app.persistentData.use then [
            homeassistant.persistentVolumes[x] for x in std.objectFields(homeassistant.persistentVolumes)
        ] + [
            homeassistant.persistentVolumeClaims[x] for x in std.objectFields(homeassistant.persistentVolumeClaims)  
        ] else []
    ) + (
        if conf.app.influxdb.use then [
            influxdb.secret,
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