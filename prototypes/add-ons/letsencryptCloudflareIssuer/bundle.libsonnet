local letsencryptComponent = import "../../components/certmanager/letsencryptCloudflare.libsonnet";

local new(conf) = {
    local namespace = conf.namespace,
    local name = conf.namePrefix,
    local labels = conf.labels,

    local letsencryptConfig = letsencryptComponent.configuration + {
        params+:: {
            letsencrypt+:: {
                email:: conf.components.certIssuer.params.letsencrypt.email,
                privateKey:: conf.components.certIssuer.params.letsencrypt.privateKey,
            },
            cloudflare+:: {
                email:: conf.components.certIssuer.params.cloudflare.email,
                apiKey:: conf.components.certIssuer.params.cloudflare.apiKey,
            },
        },
    },
    local letsencrypt = letsencryptComponent.new(namespace, name, labels, letsencryptConfig),

    secret: letsencrypt.secret,
    issuer: letsencrypt.issuer,
};

{
    new:: new,
}