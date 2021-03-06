local kube = import "../../templates/kubernetes.libsonnet";
local influxdbComponent = import "../../components/influxdb/influxdb.libsonnet";
local bitfinexCrawlerComponent = import "../../components/bitfinexCrawler/bitfinexCrawler.libsonnet";

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
        params+:: {
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

    // crawler Component
    local crawlerConfig = bitfinexCrawlerComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.crawler.imageTag,
            resources:: conf.kube.crawler.resources,
        },
        params+:: {
            tradingSymbols:: conf.app.crawler.tradingSymbols,
        },
    },
    local crawler = bitfinexCrawlerComponent.new(namespace, name, labels, crawlerConfig, influxdb),

    apiVersion: "v1",
    kind: "List",
    items: [
        crawler.deployment,
        influxdb.secret,
        influxdb.service,
        influxdb.deployment
    ] + (
        if conf.app.persistentData.use then [
            influxdb.persistentVolumes[x] for x in std.objectFields(influxdb.persistentVolumes)
        ] + [
            influxdb.persistentVolumeClaims[x] for x in std.objectFields(influxdb.persistentVolumeClaims)  
        ] else []
    ),
};

{
    new:: new,
}