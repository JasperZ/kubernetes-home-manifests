local kube = import "../../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        imageTag:: error "kube.imageTag is required",
        resources:: {
            requests:: {
                cpu:: "800m",
                memory:: "900Mi",
            },
            limits:: {
                cpu:: "1000m",
                memory:: "1Gi",
            },
        },
        certificateIssuer:: {
            name:: error "kube.certificateIssuer.name is required",
            kind:: error "kube.certificateIssuer.kind is required",
        },
    },
    params:: {
        jwtSecret:: error "params.jwtSecret is required",
        domain:: error "params.domain is required",
    },
};

local new(namespace, namePrefix, labels, config) = {
    local componentName = "onlyoffice",

    local secret = kube.secret(
        namespace, 
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        stringData =  {
            JWT_SECRET: config.params.jwtSecret,
        },
    ),

    local deployment = kube.deployment(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        [
            kube.deploymentContainer(
                componentName,
                "onlyoffice/documentserver",
                config.kube.imageTag,
                env = [
                    kube.containerEnvFromValue("JWT_ENABLED", "true"),
                    kube.containerEnvFromSecret("JWT_SECRET", secret.metadata.name, "JWT_SECRET"),
                ],
                ports = [
                    kube.containerPort(80),
                ],
                resources = kube.resources(
                    config.kube.resources.requests.cpu,
                    config.kube.resources.requests.memory,
                    config.kube.resources.limits.cpu,
                    config.kube.resources.limits.memory,
                ),
            ),
        ],
    ),

    local service = kube.service(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        deployment.metadata.labels,
        [
            kube.servicePort("http", "TCP", 80, 80),
        ],
    ),

    local certificate = kube.certificate(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        "%(domain)s-tls" % {domain: std.strReplace(config.params.domain, ".", "-")},
        config.params.domain,
        {metadata: config.kube.certificateIssuer},
    ),

    local ingress = kube.ingress(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        tls = [
            kube.ingressTls(
                [config.params.domain],
                "%(domain)s-tls" % {domain: std.strReplace(config.params.domain, ".", "-")}
            ),
        ],
        rules = [
            kube.ingressRule(
                config.params.domain,
                [
                    kube.ingressRulePath(service.metadata.name, 80),
                ],
            ),
        ],
    ),

    secret: secret,
    service: service,
    deployment: deployment,
    certificate: certificate,
    ingress: ingress,
};

{
    configuration:: configuration,
    new:: new,
}