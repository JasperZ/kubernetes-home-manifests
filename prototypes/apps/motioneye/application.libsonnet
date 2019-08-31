local kube = import "../../templates/kubernetes.libsonnet";
local motioneyeComponent = import "../../components/motioneye/motioneye.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

    // motioneye Component
    local motioneyeConfig = motioneyeComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.motioneye.imageTag,
            resources:: conf.kube.motioneye.resources,
        },
        params+:: {
            ip:: conf.app.motioneye.ip,
        },
        data+:: {
            persist:: conf.app.persistentData.use,
            nfsVolumes+:: {
                config+:: {
                    nfsServer:: conf.app.persistentData.expensive.nfsServer,
                    nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/motioneye/config",
                },
                media+:: {
                    nfsServer:: conf.app.persistentData.cheap.nfsServer,
                    nfsPath:: conf.app.persistentData.cheap.nfsRootPath + "/motioneye/media",
                },
            },
        },
    },
    local motioneye = motioneyeComponent.new(namespace, name, labels, motioneyeConfig),

    apiVersion: "v1",
    kind: "List",
    items: [
        motioneye.service,
        motioneye.deployment,
    ] + (
        if conf.app.persistentData.use then [
            motioneye.persistentVolumes[x] for x in std.objectFields(motioneye.persistentVolumes)
        ] + [
            motioneye.persistentVolumeClaims[x] for x in std.objectFields(motioneye.persistentVolumeClaims)  
        ] else []
    ),
};

{
    new:: new,
}