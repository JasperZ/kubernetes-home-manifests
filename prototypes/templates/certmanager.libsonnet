local http01Solver() = {
    http01: {
        ingress: {
          class: "nginx",
        },
    },
};

local dns01SolverCloudflare(email, apiKeySecretName, apiKeySecretKey) = {
    dns01: {
        cloudflare: {
            email: email,
            apiKeySecretRef: {
                name: apiKeySecretName,
                key: apiKeySecretKey,
            },
        },
    },
};

local acmeIssuer(namespace, name, labels, email, server, privateKeySecretName, privateKeySecretKey, solvers) = {
    apiVersion: "certmanager.k8s.io/v1alpha1",
    kind: "Issuer",
    metadata: {
        namespace: namespace,
        name: name,
        labels: labels,
    },
    spec: {
        acme: {
            email: email,
            server: server,
            privateKeySecretRef: {
                name: privateKeySecretName,
                key: privateKeySecretKey,
            },
            solvers: solvers,
        },
    },
        
};

local acmeClusterIssuer(name, labels, email, server, privateKeySecretName, privateKeySecretKey, solvers) = {
    apiVersion: "certmanager.k8s.io/v1alpha1",
    kind: "ClusterIssuer",
    metadata: {
        name: name,
        labels: labels,
    },
    spec: {
        acme: {
            email: email,
            server: server,
            privateKeySecretRef: {
                name: privateKeySecretName,
                key: privateKeySecretKey,
            },
            solvers: solvers,
        },
    },
        
};

{
    http01Solver:: http01Solver,
    dns01SolverCloudflare:: dns01SolverCloudflare,
    acmeIssuer:: acmeIssuer,
    acmeClusterIssuer:: acmeClusterIssuer,
}