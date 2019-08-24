local appTemplate = import "templates/app.libsonnet";
local confTemplate = import "templates/configuration.libsonnet";

appTemplate.newInstance(
    "default",
    "testing-nextcloud",
    {
        app: "nextcloud",
        env: "testing",
    },
    confTemplate.newConfiguration(
        confTemplate.newNextcloudConfiguration(
            "16.0.4-fpm-alpine",
            "1.17.1-alpine",
            "admin",
            "password",
            "test.jz-c.org",
        ),
        confTemplate.newCertificateConfiguration(
            "production-letsencrypt",
            "ClusterIssuer",
        ),
        true, // Enable MariaDB
        true, // Enable Redis
        true, // Enable Onlyoffice
        true, // Enable persistent data
        confTemplate.newMariadbConfiguration(
            "10.4.6-bionic",
            "password",
            "nextcloud",
            "nextcloud",
            "password",
        ),
        confTemplate.newRedisConfiguration(
            "5.0.5-alpine",
        ),
        confTemplate.newOnlyofficeConfiguration(
            "5.2.8.24",
            "test-office.jz-c.org",
            "fgwdzock65gWVeCUiY3AU2Yi",
        ),
        confTemplate.newPersistenceConfiguration(
            "proxmox.zhc.x64.me",
            "/datacenter_250gb/k8s/testing-volumes/nextcloud-fpm",
            "proxmox.zhc.x64.me",
            "/datacenter_250gb/k8s/testing-volumes/nextcloud-fpm",
        )
    ),
)