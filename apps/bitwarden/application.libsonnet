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
        stringData = {
            ADMIN_TOKEN: conf.app.bitwarden.adminToken,
        } + (
            if conf.app.bitwarden.smtp.use then {
                SMTP_HOST: conf.app.bitwarden.smtp.host,
                SMTP_FROM: conf.app.bitwarden.smtp.from,
                SMTP_PORT: conf.app.bitwarden.smtp.port,
                SMTP_SSL: conf.app.bitwarden.smtp.ssl,
                SMTP_USERNAME: conf.app.bitwarden.smtp.username,
                SMTP_PASSWORD: conf.app.bitwarden.smtp.password,
            } else {}
        ),
    ),

    // bitwarden Component
    local bitwardenComponentName = "bitwarden",
    local bitwardenDataDir = "data",

    // bitwarden PersistentVolumes
    local bitwardenPersistentVolumes = {
        data: kube.persistentVolume(
            name + "-" + bitwardenComponentName + "-" + bitwardenDataDir,
            labels + {component: bitwardenComponentName},
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + bitwardenComponentName + "/" + bitwardenDataDir,
        ),
    },

    // bitwarden PersistentVolumeClaims
    local bitwardenPersistentVolumeClaims = {
        data: kube.persistentVolumeClaim(
            namespace,
            bitwardenPersistentVolumes.data.metadata.name,
            labels + {component: bitwardenComponentName},
            bitwardenPersistentVolumes.data.metadata.name,
        ),
    },
    
    // bitwarden Deployment
    local bitwardenDeployment = kube.deployment(
        namespace,
        name + "-" + bitwardenComponentName,
        labels + {component: bitwardenComponentName},
        [
            kube.deploymentContainer(
                bitwardenComponentName,
                "bitwardenrs/server",
                conf.app.bitwarden.imageTag,
                env = [
                    kube.containerEnvFromValue("DOMAIN", "https://%s" % conf.app.bitwarden.domain),
                    kube.containerEnvFromValue("WEBSOCKET_ENABLED", "true"),
                    kube.containerEnvFromValue("SIGNUPS_ALLOWED", conf.app.bitwarden.signupsAllowed),
                    kube.containerEnvFromSecret("ADMIN_TOKEN", secret.metadata.name, "ADMIN_TOKEN"),
                ] + (
                    if conf.app.bitwarden.smtp.use then [
                        kube.containerEnvFromSecret("SMTP_HOST", secret.metadata.name, "SMTP_HOST"),
                        kube.containerEnvFromSecret("SMTP_FROM", secret.metadata.name, "SMTP_FROM"),
                        kube.containerEnvFromSecret("SMTP_PORT", secret.metadata.name, "SMTP_PORT"),
                        kube.containerEnvFromSecret("SMTP_SSL", secret.metadata.name, "SMTP_SSL"),
                        kube.containerEnvFromSecret("SMTP_USERNAME", secret.metadata.name, "SMTP_USERNAME"),
                        kube.containerEnvFromSecret("SMTP_PASSWORD", secret.metadata.name, "SMTP_PASSWORD"),
                    ] else []
                ),
                ports = [
                    kube.containerPort(80),
                    kube.containerPort(3012),
                ],
                volumeMounts = (
                    if conf.app.persistentData.use then [
                        kube.containerVolumeMount(bitwardenDataDir, "/data"),
                    ] else []
                ),
                resources = conf.kube.bitwarden.resources,
            ),
        ],
        volumes = (
            if conf.app.persistentData.use then [
                kube.deploymentVolumePVC(bitwardenDataDir, bitwardenPersistentVolumeClaims.data.metadata.name),
            ] else []
        ),
    ),

    // bitwarden Service
    local bitwardenService = kube.service(
        namespace,
        name + "-" + bitwardenComponentName,
        labels + {component: bitwardenComponentName},
        bitwardenDeployment.metadata.labels,
        [
            kube.servicePort("http", "TCP", 80, 80),
            kube.servicePort("websocket", "TCP", 3012, 3012),
        ],
    ),

    // bitwarden Certificate
    local bitwardenCertificate = kube.certificate(
        namespace,
        name + "-" + bitwardenComponentName,
        labels + {component: bitwardenComponentName},
        "%(domain)s-tls" % {domain: std.strReplace(conf.app.bitwarden.domain, ".", "-")},
        conf.app.bitwarden.domain,
        {metadata: conf.kube.certificateIssuer},
    ),

    // bitwarden Ingress
    local bitwardenIngress = kube.ingress(
        namespace,
        name + "-" + bitwardenComponentName,
        labels + {component: bitwardenComponentName},
        tls = [
            kube.ingressTls(
                [conf.app.bitwarden.domain],
                "%(domain)s-tls" % {domain: std.strReplace(conf.app.bitwarden.domain, ".", "-")}
            ),
        ],
        rules = [
            kube.ingressRule(
                conf.app.bitwarden.domain,
                [
                    kube.ingressRulePath(bitwardenService.metadata.name, 80, "/"),
                    kube.ingressRulePath(bitwardenService.metadata.name, 80, "/notifications/hub/negotiate"),
                    kube.ingressRulePath(bitwardenService.metadata.name, 3012, "/notifications/hub"),
                ],
            ),
        ],
    ),

    apiVersion: "v1",
    kind: "List",
    items: [
        secret,
        bitwardenDeployment,
        bitwardenService,
        bitwardenCertificate,
        bitwardenIngress,

    ] + (
        if conf.app.persistentData.use then [
            bitwardenPersistentVolumes[x] for x in std.objectFields(bitwardenPersistentVolumes)
        ] + [
            bitwardenPersistentVolumeClaims[x] for x in std.objectFields(bitwardenPersistentVolumeClaims)  
        ] else []
    ),
};

{
    new:: new,
}