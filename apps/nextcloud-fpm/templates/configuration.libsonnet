local newConfiguration(
        nextcloudConfig, certIssuer, useMariadb, useRedis, useOnlyoffice, persistentData, 
        mariadbConfig=null, redisConfig=null, onlyofficeConfig=null, persistentDataConfig=null) = {
    nextcloud: nextcloudConfig,
    certificateIssuer: certIssuer,
    useMariadb: useMariadb,
    useRedis: useRedis,
    useOnlyoffice: useOnlyoffice,
    mariadb: mariadbConfig,
    redis: redisConfig,
    onlyoffice: onlyofficeConfig,
    persistentData: persistentData,
    data: persistentDataConfig,
};

local newNextcloudConfiguration(imageTag, nginxImageTag, adminUser, adminUserPassword, domain) = {
    imageTag: imageTag,
    nginxImageTag: nginxImageTag,
    adminUser: adminUser,
    adminPassword: adminUserPassword,
    domain: domain,
};

local newMariadbConfiguration(imageTag, rootPassword, databaseName, user, userPassword) = {
    imageTag: imageTag,
    rootPassword: rootPassword,
    databaseName: databaseName,
    user: user,
    userPassword: userPassword,
};

local newRedisConfiguration(imageTag) = {
    imageTag: imageTag,
};

local newOnlyofficeConfiguration(imageTag, domain, jwtSecret) = {
    imageTag: imageTag,
    domain: domain,
    jwtSecret: jwtSecret,
};

local newCertificateConfiguration(issuerName, issuerKind) = {
    name: issuerName,
    kind: issuerKind,
};

local newPersistenceConfiguration(fastNfsServer, fastNfsRootPath, slowNfsServer, slowNfsRootPath) = {
    fast: {
        nfsServer: fastNfsServer,
        nfsRootPath: fastNfsRootPath,
    },
    slow: {
        nfsServer: slowNfsServer,
        nfsRootPath: slowNfsRootPath,
    },
};

{
    newConfiguration:: newConfiguration,
    newNextcloudConfiguration:: newNextcloudConfiguration,
    newMariadbConfiguration:: newMariadbConfiguration,
    newRedisConfiguration:: newRedisConfiguration,
    newOnlyofficeConfiguration:: newOnlyofficeConfiguration,
    newCertificateConfiguration:: newCertificateConfiguration,
    newPersistenceConfiguration:: newPersistenceConfiguration,
}