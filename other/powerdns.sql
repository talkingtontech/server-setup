Create DATABASE powerdns;

CREATE USER 'powerdns'@'localhost' IDENTIFIED BY 'mypass';
GRANT ALL PRIVILEGES ON powerdns.* TO 'powerdns'@'localhost';

USE powerdns;

SET storage_engine=INNODB;

CREATE TABLE domains (
id              INT          AUTO_INCREMENT,
name            VARCHAR(255) NOT NULL,
master          VARCHAR(128) DEFAULT NULL,
last_check      INT          DEFAULT NULL,
type            VARCHAR(6)   NOT NULL,
notified_serial INT          DEFAULT NULL,
account         VARCHAR(40)  DEFAULT NULL,
PRIMARY KEY(id)
);

CREATE UNIQUE INDEX name_index ON domains(name);

CREATE TABLE records (
id          INT          AUTO_INCREMENT,
domain_id   INT          DEFAULT NULL,
name        VARCHAR(255) DEFAULT NULL,
type        VARCHAR(6)   DEFAULT NULL,
content     VARCHAR(255) DEFAULT NULL,
ttl         INT          DEFAULT NULL,
prio        INT          DEFAULT NULL,
change_date INT          DEFAULT NULL,
PRIMARY KEY(id)
);

CREATE INDEX rec_name_index ON records(name);
CREATE INDEX nametype_index ON records(name, type);
CREATE INDEX domain_id ON records(domain_id);

CREATE TABLE supermasters (
ip         VARCHAR(25)  NOT NULL,
nameserver VARCHAR(255) NOT NULL,
account    VARCHAR(40)  DEFAULT NULL
);


CREATE table domainmetadata (
 id        INT auto_increment,
 domain_id INT NOT NULL,
 kind      VARCHAR(16),
 content   TEXT,
 PRIMARY KEY(id)
);

CREATE INDEX domainmetaidindex ON domainmetadata(domain_id);

CREATE TABLE cryptokeys (
 id        INT auto_increment,
 domain_id INT NOT NULL,
 flags     INT NOT NULL,
 active    BOOLEAN,
 content   TEXT,
 PRIMARY KEY(id)
);

CREATE INDEX domainidindex ON cryptokeys(domain_id);

ALTER TABLE records ADD ordername VARCHAR(255) BINARY;
ALTER TABLE records ADD auth bool;
CREATE INDEX recordorder ON records(domain_id, ordername);

CREATE TABLE tsigkeys (
 id        INT auto_increment,
 name      VARCHAR(255),
 algorithm VARCHAR(50),
 secret    VARCHAR(255),
 PRIMARY KEY(id)
);

CREATE UNIQUE INDEX namealgoindex ON tsigkeys(name, algorithm);
ALTER TABLE records CHANGE COLUMN type type VARCHAR(10);