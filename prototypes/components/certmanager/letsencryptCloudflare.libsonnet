local kube = import "../../templates/kubernetes.libsonnet";
local certmanager = import "../../templates/certmanager.libsonnet";

local configuration = {
    params:: {
        letsencrypt:: {
            email:: error "letsencrypt.email is required",
            privateKey:: error "letsencrypt.privateKey is required",
        },
        cloudflare:: {
            email:: error "cloudflare.email is required",
            apiKey:: error "cloudflare.apiKey is required",
        },
    },
};

local new(namespace, namePrefix, labels, config) = {
    local componentName = "certmanager-letsencrypt",

    local secret = kube.secret(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        stringData = {
            LETSENCRYPT_PRIVATE_KEY: config.params.letsencrypt.privateKey,
            CLOUDFLARE_API_KEY: config.params.cloudflare.apiKey,
        },
    ),

    local issuer = certmanager.acmeIssuer(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        config.params.letsencrypt.email,
        "https://acme-v02.api.letsencrypt.org/directory",
        secret.metadata.name,
        "LETSENCRYPT_PRIVATE_KEY",
        [
            certmanager.dns01SolverCloudflare(
                config.params.cloudflare.email,
                secret.metadata.name,
                "CLOUDFLARE_API_KEY",
            ),
        ],
    ),

    secret: secret,
    issuer: issuer,
};

{
    configuration:: configuration,
    new:: new,
}