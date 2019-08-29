local kube = import "../../templates/kubernetes.libsonnet";
local bitwardenComponent = import "../../components/bitwarden/bitwarden.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

    // bitwarden Component
    local bitwardenConfig = bitwardenComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.bitwarden.imageTag,
            resources:: conf.kube.bitwarden.resources,
            certificateIssuer+:: {
                name:: conf.kube.certificateIssuer.name,
                kind:: conf.kube.certificateIssuer.kind,
            },
        },
        app+:: {
            adminToken:: conf.app.bitwarden.adminToken,
            signupsAllowed:: conf.app.bitwarden.signupsAllowed,
            domain:: conf.app.bitwarden.domain,
            smtp+:: {
                use:: conf.app.bitwarden.smtp.use,
                host:: conf.app.bitwarden.smtp.host,
                from:: conf.app.bitwarden.smtp.from,
                port:: conf.app.bitwarden.smtp.port,
                ssl:: conf.app.bitwarden.smtp.ssl,
                username:: conf.app.bitwarden.smtp.username,
                password:: conf.app.bitwarden.smtp.password,
            },
        },
        data+:: {
            persist:: conf.app.persistentData.use,
            nfsVolumes+:: {
                data+:: {
                    nfsServer:: conf.app.persistentData.expensive.nfsServer,
                    nfsPath:: conf.app.persistentData.expensive.nfsRootPath + "/bitwarden/data",
                },
            },
        },
    },
    local bitwarden = bitwardenComponent.new(namespace, name, labels, bitwardenConfig),

    apiVersion: "v1",
    kind: "List",
    items: [
        bitwarden.secret,
        bitwarden.service,
        bitwarden.deployment,
        bitwarden.certificate,
        bitwarden.ingress,

    ] + (
        if conf.app.persistentData.use then [
            bitwarden.persistentVolumes[x] for x in std.objectFields(bitwarden.persistentVolumes)
        ] + [
            bitwarden.persistentVolumeClaims[x] for x in std.objectFields(bitwarden.persistentVolumeClaims)  
        ] else []
    ),
};

{
    new:: new,
}