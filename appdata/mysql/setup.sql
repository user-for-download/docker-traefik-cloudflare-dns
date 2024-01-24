--authelia
CREATE USER 'authelia' @'%' IDENTIFIED BY 'see storage_mysql_password';
GRANT USAGE ON *.* TO 'authelia' @'%' REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
CREATE DATABASE IF NOT EXISTS `authelia`;
GRANT ALL PRIVILEGES ON `authelia`.* TO 'authelia' @'%';
--owncloud
CREATE USER 'owncloud' @'%' IDENTIFIED BY 'see owncloud.yml';
GRANT USAGE ON *.* TO 'owncloud' @'%' REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
CREATE DATABASE IF NOT EXISTS `owncloud`;
GRANT ALL PRIVILEGES ON `owncloud`.* TO 'owncloud' @'%';