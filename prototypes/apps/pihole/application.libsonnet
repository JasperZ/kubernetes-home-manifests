local kube = import "../../templates/kubernetes.libsonnet";
local piholeComponent = import "../../components/pihole/pihole.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

    // Pi-hole Component
    local piholeConfig = piholeComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.pihole.imageTag,
            resources:: conf.kube.pihole.resources,
        },
        params+:: {
            ip:: conf.app.pihole.ip,
            webPassword:: conf.app.pihole.webPassword,
        },
        // data+:: {
        //     persist:: conf.app.persistentData.use,
        //     nfsVolumes+:: {
        //         database+:: {
        //             nfsServer:: conf.app.persistentData.expensive.nfsServer,
        //             nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/urbackup/database",
        //         },
        //         backups+:: {
        //             nfsServer:: conf.app.persistentData.cheap.nfsServer,
        //             nfsPath:: conf.app.persistentData.cheap.nfsRootPath + "/urbackup/backups",
        //         },
        //     },
        // },
    },
    local pihole = piholeComponent.new(namespace, name, labels, piholeConfig),

    apiVersion: "v1",
    kind: "List",
    items: [
        pihole.tcpService,
        pihole.udpService,
        pihole.deployment,
    ] // + (
    //     if conf.app.persistentData.use then [
    //         urbackup.persistentVolumes[x] for x in std.objectFields(urbackup.persistentVolumes)
    //     ] + [
    //         urbackup.persistentVolumeClaims[x] for x in std.objectFields(urbackup.persistentVolumeClaims)  
    //     ] else []
    // ),
};

{
    new:: new,
}