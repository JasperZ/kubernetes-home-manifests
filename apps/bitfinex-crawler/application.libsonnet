local kube = import "../../templates/kubernetes.libsonnet";
local influxdbComponent = import "../../components/influxdb.libsonnet";
local bitfinexCrawlerComponent = import "../../components/bitfinexCrawler.libsonnet";

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
    local influxdb = influxdbComponent.new(namespace, name, labels, 8086, influxdbConfig),
    local influxdbSecret = influxdb.secret,
    local influxdbPersistentVolumes = influxdb.persistentVolumes,
    local influxdbPersistentVolumeClaims = influxdb.persistentVolumeClaims,
    local influxdbService = influxdb.service,
    local influxdbDeployment = influxdb.deployment,

    // crawler Component
    local crawlerConfig = bitfinexCrawlerComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.crawler.imageTag,
            resources:: conf.kube.crawler.resources,
        },
        app+:: {
            tradingSymbols:: conf.app.crawler.tradingSymbols,
        },
    },
    local crawler = bitfinexCrawlerComponent.new(namespace, name, labels, influxdb, crawlerConfig),
    local crawlerDeployment = crawler.deployment,

    apiVersion: "v1",
    kind: "List",
    items: [
        crawlerDeployment,
        influxdbSecret,
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