{
    namespace:: error "namespace is required",
    namePrefix:: error "namePrefix is required",
    labels:: error "labels is required",
    components:: {
        certIssuer:: {
            params:: {
                letsencrypt:: {
                    email:: error "components.certIssuer.params.letsencrypt.email is required",
                    privateKey:: error "components.certIssuer.params.letsencrypt.privateKey is required",
                },
                cloudflare:: {
                    email:: error "components.certIssuer.params.cloudflare.email is required",
                    apiKey:: error "components.certIssuer.params.cloudflare.apiKey is required",
                },
            },
        },
    },
}
