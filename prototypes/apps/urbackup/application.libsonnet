local kube = import "../../templates/kubernetes.libsonnet";
local urbackupComponent = import "../../components/urbackup/urbackup.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

    // Urbackup Component
    local urbackupConfig = urbackupComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.urbackup.imageTag,
            resources:: conf.kube.urbackup.resources,
        },
        params+:: {
            ip:: conf.app.urbackup.ip,
        },
        data+:: {
            persist:: conf.app.persistentData.use,
            nfsVolumes+:: {
                database+:: {
                    nfsServer:: conf.app.persistentData.expensive.nfsServer,
                    nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/urbackup/database",
                },
                backups+:: {
                    nfsServer:: conf.app.persistentData.cheap.nfsServer,
                    nfsPath:: conf.app.persistentData.cheap.nfsRootPath + "/urbackup/backups",
                },
            },
        },
    },
    local urbackup = urbackupComponent.new(namespace, name, labels, urbackupConfig),

    apiVersion: "v1",
    kind: "List",
    items: [
        urbackup.service,
        urbackup.deployment,
    ] + (
        if conf.app.persistentData.use then [
            urbackup.persistentVolumes[x] for x in std.objectFields(urbackup.persistentVolumes)
        ] + [
            urbackup.persistentVolumeClaims[x] for x in std.objectFields(urbackup.persistentVolumeClaims)  
        ] else []
    ),
};

{
    new:: new,
}