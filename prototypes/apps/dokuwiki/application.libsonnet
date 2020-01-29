local kube = import "../../templates/kubernetes.libsonnet";
local dokuwikiComponent = import "../../components/dokuwiki/dokuwiki.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

    // dokuwiki Component
    local dokuwikiConfig = dokuwikiComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.dokuwiki.imageTag,
            resources:: conf.kube.dokuwiki.resources,
            certificateIssuer+:: {
                name:: conf.kube.certificateIssuer.name,
                kind:: conf.kube.certificateIssuer.kind,
            },
        },
        params+:: {
            adminUsername:: conf.app.dokuwiki.adminUsername,
            adminPassword:: conf.app.dokuwiki.adminPassword,
            adminFullName:: conf.app.dokuwiki.adminFullName,
            adminEmail:: conf.app.dokuwiki.adminEmail,
            wikiName:: conf.app.dokuwiki.wikiName,
            ip:: conf.app.dokuwiki.ip,
        },
        data+:: {
            persist:: conf.app.persistentData.use,
            nfsVolumes+:: {
                data+:: {
                    nfsServer:: conf.app.persistentData.expensive.nfsServer,
                    nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/dokuwiki/data",
                },
            },
        },
    },
    local dokuwiki = dokuwikiComponent.new(namespace, name, labels, dokuwikiConfig),

    apiVersion: "v1",
    kind: "List",
    items: [
        dokuwiki.secret,
        dokuwiki.service,
        dokuwiki.deployment,

    ] + (
        if conf.app.persistentData.use then [
            dokuwiki.persistentVolumes[x] for x in std.objectFields(dokuwiki.persistentVolumes)
        ] + [
            dokuwiki.persistentVolumeClaims[x] for x in std.objectFields(dokuwiki.persistentVolumeClaims)  
        ] else []
    ),
};

{
    new:: new,
}