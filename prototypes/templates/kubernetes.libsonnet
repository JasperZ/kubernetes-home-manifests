local service(namespace, name, labels, selector, ports) = {
    apiVersion: "v1",
    kind: "Service",
    metadata: {
        name: name,
        namespace: namespace,
        labels: labels,
    },
    spec: {
        selector: selector,
        ports: ports,
    },
};

local servicePort(name, protocol, port, targetPort) = {
    name: name,
    protocol: protocol,
    port: port,
    targetPort: targetPort,
};

local resources(cpuReq, memReq, cpuLimit, memLimit) = {
    requests: {
        cpu: cpuReq,
        memory: memReq,
    },
    limits: {
        cpu: cpuLimit,
        memory: memLimit,
    },
};

local certificate(namespace, name, labels, secretName, dnsName, issuer) = {
    apiVersion: "certmanager.k8s.io/v1alpha1",
    kind: "Certificate",
    metadata: {
        name: name,
        namespace: namespace,
        labels: labels,
    },
    spec: {
        secretName: secretName,
        dnsNames: [
            dnsName,
        ],
        issuerRef: {
            name: issuer.metadata.name,
            kind: issuer.metadata.kind,
        },
    },
};

local ingressTls(hosts, secretName) = {
    hosts: hosts,
    secretName: secretName,
};

local ingressRulePath(serviceName, servicePort, path=null) = {
    [if path != null then "path"]: path,
    backend: {
        serviceName: serviceName,
        servicePort: servicePort,
    },
};

local ingressRule(host, paths) = {
    host: host,
    http: {
        paths: paths,
    },
};

local ingress(namespace, name, labels, tls=[], rules=[]) = {
    apiVersion: "networking.k8s.io/v1beta1",
    kind: "Ingress",
    metadata: {
        name: name,
        namespace: namespace,
        labels: labels,
        annotations: {
            "kubernetes.io/ingress.class": "nginx",
            "nginx.ingress.kubernetes.io/proxy-body-size": "16G",
        },
    },
    spec: {
        tls: tls,
        rules: rules,
    },
};

local secret(namespace, name, labels, stringData={}, encodedData={}) = {
    apiVersion: "v1",
    kind: "Secret",
    metadata: {
        local hash = std.substr(std.md5(std.toString([stringData, encodedData])), 0, 8),

        name: name + "-" + hash,
        namespace: namespace,
        labels: labels,
    },
    type: "Opaque",
    stringData: stringData,
    data: encodedData,
};

local persistentVolume(name, labels, nfsServer, nfsPath, nfsVersion=4) = {
    apiVersion: "v1",
    kind: "PersistentVolume",
    metadata: {
        name: name,
        labels: labels,
    },
    spec: {
        capacity: {
            storage: "5Gi",
        },
        volumeMode: "Filesystem",
        accessModes: [
            "ReadWriteMany"
        ],
        persistentVolumeReclaimPolicy: "Retain",
        mountOptions: [
            "nfsvers=" + nfsVersion
        ],
        nfs: {
            server: nfsServer,
            path: nfsPath,
        },
    },
};

local persistentVolumeClaim(namespace, name, labels, volumeName) = {
    apiVersion: "v1",
    kind: "PersistentVolumeClaim",
    metadata: {
        name: name,
        namespace: namespace,
        labels: labels,
    },
    spec: {
        volumeMode: "Filesystem",
        accessModes: [
            "ReadWriteMany"
        ],
        resources: {
            requests: {
                storage: "5Gi",
            },
        },
        volumeName:volumeName,
    },
};

local configMap(namespace, name, labels, data) = {
    apiVersion: "v1",
    kind: "ConfigMap",
    metadata: {
        local hash = std.substr(std.md5(std.toString($.data)), 0, 8),

        name: name + "-" + hash,
        namespace: namespace,
        labels: labels,
    },
    data: data,
};

local deploymentContainer(name, image, imageTag, command=[], env=[], ports=[], volumeMounts=[], resources={}) = {
    name: name,
    image: image + ":" + imageTag,
    imagePullPolicy: (
        if imageTag == "latest" then
            "Always"
        else
            "IfNotPresent"
    ),
    command: command,
    env: env,
    ports: ports,
    volumeMounts: volumeMounts,
    resources: resources,
};

local deploymentVolumePVC(name, claimName) = {
    name: name,
    persistentVolumeClaim: {
        claimName: claimName,
    },
};

local deploymentVolumeEmptyDir(name) = {
    name: name,
    emptyDir: {},
};

local deploymentVolumeConfigMap(name, configMapName) = {
    name: name,
    configMap: {
        name: configMapName,
    },
};

local deployment(namespace, name, labels, containers, initContainers=[], volumes=[]) = {
    apiVersion: "apps/v1",
    kind: "Deployment",
    metadata: {
        name: name,
        namespace: namespace,
        labels: labels,
    },
    spec: {
        replicas: 1,
        selector: {
            matchLabels: $.metadata.labels,
        },
        template: {
            metadata: {
                labels: $.metadata.labels,
            },
            spec: {
                volumes: volumes,
                initContainers: initContainers,
                containers: containers,
            },
        },
    },
};

local cronJob(namespace, name, labels, schedule, containers, initContainers=[], volumes=[]) = {
    apiVersion: "batch/v1beta1",
    kind: "CronJob",
    metadata: {
        name: name,
        namespace: namespace,
        labels: labels,
    },
    spec: {
        schedule: schedule,
        jobTemplate: {
            spec: {
                template: {
                    spec: {
                        volumes: volumes,
                        initContainers: initContainers,
                        containers: containers,
                        restartPolicy: "OnFailure",
                    },
                },
            },
        },
    },
};

local containerEnvFromSecret(name, secretName, secretKey) = {
    name: name,
    valueFrom: {
        secretKeyRef: {
            name: secretName,
            key: secretKey,
        },
    },
};

local containerEnvFromValue(name, value) = {
    name: name,
    value: value,
};

local containerPort(port, protocol="TCP") = {
    containerPort: port,
    protocol: protocol,
};

local containerVolumeMount(name, mountPath) = {
    name: name,
    mountPath: mountPath,
};

{
    service:: service,
    servicePort:: servicePort,
    resources:: resources,
    certificate:: certificate,
    ingressTls:: ingressTls,
    ingressRulePath:: ingressRulePath,
    ingressRule:: ingressRule,
    ingress:: ingress,
    secret:: secret,
    persistentVolume:: persistentVolume,
    persistentVolumeClaim:: persistentVolumeClaim,
    configMap:: configMap,
    deploymentContainer:: deploymentContainer,
    deploymentVolumePVC:: deploymentVolumePVC,
    deploymentVolumeEmptyDir:: deploymentVolumeEmptyDir,
    deploymentVolumeConfigMap:: deploymentVolumeConfigMap,
    deployment:: deployment,
    cronJob:: cronJob,
    containerEnvFromSecret:: containerEnvFromSecret,
    containerEnvFromValue:: containerEnvFromValue,
    containerPort:: containerPort,
    containerVolumeMount:: containerVolumeMount,
}
