DROP SCHEMA IF EXISTS torrent;
CREATE SCHEMA torrent;
USE torrent;

CREATE TABLE category
(
    name VARCHAR(10) PRIMARY KEY NOT NULL
);

CREATE TABLE resource
(
    id            BINARY(16) PRIMARY KEY,
    upload_time   TIMESTAMP                          NOT NULL,
    leeches       SMALLINT                           NOT NULL,
    seeders       SMALLINT                           NOT NULL,
    info_sha256   BLOB                               NOT NULL,
    url           TEXT                               NOT NULL,
    is_legal      BOOLEAN,
    size_in_bytes BIGINT CHECK ( size_in_bytes > 0 ) NOT NULL
);

CREATE TABLE uploader
(
    id               BINARY(16) PRIMARY KEY,
    name             VARCHAR(50) UNIQUE NOT NULL,
    recently_active  TIMESTAMP          NOT NULL,
    first_logged_in  TIMESTAMP          NOT NULL,
    recently_used_ip INT UNSIGNED       NOT NULL,
    first_used_ip    INT UNSIGNED       NOT NULL
);

CREATE TABLE share
(
    resource_id BINARY(16) PRIMARY KEY,
    title       VARCHAR(256) NOT NULL,
    description VARCHAR(512),
    uploader_id BINARY(16)   NOT NULL,
    category    VARCHAR(10)  NOT NULL,
    FOREIGN KEY (resource_id) REFERENCES resource (id) ON DELETE CASCADE,
    FOREIGN KEY (uploader_id) REFERENCES uploader (id),
    FOREIGN KEY (category) REFERENCES category (name)
);

CREATE TABLE film_archetype
(
    id                BINARY(16) PRIMARY KEY,
    title             VARCHAR(256)                            NOT NULL,
    format            VARCHAR(256)                            NOT NULL,
    language_code     VARCHAR(2)                              NOT NULL,
    resolution        VARCHAR(9)                              NOT NULL,
    release_year      VARCHAR(4)                              NOT NULL,
    length_in_minutes SMALLINT CHECK ( length_in_minutes > 0) NOT NULL
);

CREATE TABLE film_instance
(
    share_id     BINARY(16) PRIMARY KEY,
    archetype_id BINARY(16),
    FOREIGN KEY (share_id) REFERENCES share (resource_id) ON DELETE CASCADE,
    FOREIGN KEY (archetype_id) REFERENCES film_archetype (id)
);

CREATE TABLE music_archetype
(
    id           BINARY(16) PRIMARY KEY,
    length_epoch SMALLINT CHECK ( length_epoch > 0) NOT NULL,
    format       VARCHAR(6)                         NOT NULL,
    album_name   VARCHAR(256)                       NOT NULL,
    release_year VARCHAR(4)
);

CREATE TABLE music_instance
(
    share_id     BINARY(16) PRIMARY KEY,
    archetype_id BINARY(16),
    FOREIGN KEY (share_id) REFERENCES share (resource_id) ON DELETE CASCADE,
    FOREIGN KEY (archetype_id) REFERENCES music_archetype (id)
);

CREATE TABLE operating_system
(
    name VARCHAR(10) UNIQUE PRIMARY KEY
);

CREATE TABLE game_archetype
(
    id               BINARY(16) PRIMARY KEY,
    title            VARCHAR(256) NOT NULL,
    studio           VARCHAR(256) NOT NULL,
    language_code    VARCHAR(2)   NOT NULL,
    release_year     VARCHAR(4)   NOT NULL,
    operating_system VARCHAR(10)  NOT NULL,
    FOREIGN KEY (operating_system) REFERENCES operating_system (name)
);

CREATE TABLE game_instance
(
    share_id     BINARY(16) PRIMARY KEY,
    archetype_id BINARY(16),
    FOREIGN KEY (share_id) REFERENCES share (resource_id) ON DELETE CASCADE,
    FOREIGN KEY (archetype_id) REFERENCES game_archetype (id)
);

CREATE TABLE book_archetype
(
    id            BINARY(16) PRIMARY KEY,
    title         VARCHAR(256) NOT NULL,
    author        VARCHAR(256) NOT NULL,
    language_code VARCHAR(2)   NOT NULL,
    ISBN          VARCHAR(13)  NOT NULL
);

CREATE TABLE audio_book
(
    id             BINARY(16) PRIMARY KEY,
    studio         VARCHAR(256)                       NOT NULL,
    read_by        VARCHAR(256)                       NOT NULL,
    language_code  VARCHAR(2)                         NOT NULL,
    length_epoch   SMALLINT CHECK ( length_epoch > 0) NOT NULL,
    format         VARCHAR(6)                         NOT NULL,
    release_year   VARCHAR(4)                         NOT NULL,
    source_book_id BINARY(16)                         NOT NULL,
    FOREIGN KEY (source_book_id) REFERENCES book_archetype (id)
);

CREATE TABLE ebook
(
    id             BINARY(16) PRIMARY KEY,
    studio         VARCHAR(256) NOT NULL,
    format         VARCHAR(6)   NOT NULL,
    release_year   VARCHAR(4)   NOT NULL,
    source_book_id BINARY(16)   NOT NULL,
    FOREIGN KEY (source_book_id) REFERENCES book_archetype (id)
);

CREATE TABLE book_instance
(
    share_id     BINARY(16) PRIMARY KEY,
    archetype_id BINARY(16),
    FOREIGN KEY (share_id) REFERENCES share (resource_id) ON DELETE CASCADE,
    FOREIGN KEY (archetype_id) REFERENCES book_archetype (id)
);

-- INDEXES
CREATE FULLTEXT INDEX std ON share (description, title);
CREATE INDEX ftitle ON film_archetype (title);
CREATE INDEX gtitle ON game_archetype (title);
CREATE INDEX btitle ON book_archetype (title);
CREATE INDEX bau ON book_archetype (author);
CREATE INDEX abr ON audio_book (read_by);


INSERT INTO operating_system (name)
VALUES ('Windows 10');
INSERT INTO operating_system (name)
VALUES ('SteamOs');
INSERT INTO operating_system (name)
VALUES ('Windows 11');
INSERT INTO operating_system (name)
VALUES ('Linux');
INSERT INTO operating_system (name)
VALUES ('OSX');

INSERT INTO category (name)
VALUES ('film');
INSERT INTO category (name)
VALUES ('ebook');
INSERT INTO category (name)
VALUES ('audiobook');
INSERT INTO category (name)
VALUES ('music');
INSERT INTO category (name)
VALUES ('game');


CREATE USER IF NOT EXISTS contributor;
CREATE USER IF NOT EXISTS torrent_admin IDENTIFIED BY 'passwd';


DROP VIEW IF EXISTS all_shares;
CREATE VIEW all_shares AS
SELECT s.title,
       s.category,
       torrent.resource.seeders,
       torrent.resource.leeches,
       torrent.resource.info_sha256,
       torrent.resource.is_legal,
       torrent.resource.size_in_bytes,
       torrent.resource.upload_time
FROM torrent.share s
         INNER JOIN torrent.resource ON torrent.resource.id = s.resource_id
         INNER JOIN torrent.uploader on torrent.uploader.id = s.uploader_id;

DROP VIEW IF EXISTS share_movie_details;
CREATE VIEW share_movie_details AS
SELECT s.title  AS share_title,
       s.description,
       r.seeders,
       r.leeches,
       r.info_sha256,
       r.is_legal,
       r.size_in_bytes,
       r.upload_time,
       fa.title AS film_title,
       fa.length_in_minutes,
       fa.format,
       fa.release_year,
       fa.language_code,
       fa.resolution
FROM torrent.share s
         INNER JOIN torrent.resource r ON r.id = s.resource_id
         INNER JOIN torrent.uploader u on u.id = s.uploader_id
         INNER JOIN torrent.film_instance fi on fi.share_id = s.resource_id
         INNER JOIN torrent.film_archetype fa on fa.id = fi.archetype_id
;

DROP VIEW IF EXISTS admin_example_view;
CREATE VIEW admin_example_view AS
SELECT s.resource_id,
       s.title,
       s.category,
       torrent.resource.seeders,
       torrent.resource.leeches,
       torrent.resource.info_sha256,
       torrent.resource.is_legal,
       torrent.resource.size_in_bytes,
       torrent.resource.upload_time,
       u.name,
       u.first_used_ip,
       u.recently_used_ip
FROM torrent.share s
         INNER JOIN torrent.resource ON torrent.resource.id = s.resource_id
         INNER JOIN torrent.uploader u on u.id = s.uploader_id;

DROP VIEW IF EXISTS suspicious_urls_in_a_week;
CREATE VIEW suspicious_urls_in_a_week AS
SELECT *
FROM torrent.resource r
WHERE upload_time < current_date - 7
  AND r.url LIKE 'http://%';


DROP VIEW IF EXISTS suspicious_ips;
CREATE VIEW suspicious_ips AS
WITH all_ips_by_user AS (SELECT u.first_used_ip
                         FROM torrent.uploader u
                         UNION ALL
                         SELECT u2.recently_used_ip
                         FROM torrent.uploader u2)
SELECT COUNT(first_used_ip) AS count_suspicious_ips
FROM all_ips_by_user
WHERE first_used_ip BETWEEN INET_ATON('10.43.72.0') AND INET_ATON('100.43.72.255');

GRANT ALL PRIVILEGES ON `torrent`.* TO torrent_admin;
GRANT SELECT ON share_movie_details TO contributor;


DELIMITER $$

CREATE FUNCTION is_ip_in_ranges(ip_address VARCHAR(15), range_starts TEXT, range_ends TEXT)
    RETURNS BOOLEAN
    DETERMINISTIC
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE start_ip INT;
    DECLARE end_ip INT;
    DECLARE range_length INT;
    DECLARE ip INT;

    SET ip = INET_ATON(ip_address);

    SET range_length = LENGTH(range_starts) - LENGTH(REPLACE(range_starts, ',', '')) + 1;

    IF range_length <> (LENGTH(range_ends) - LENGTH(REPLACE(range_ends, ',', '')) + 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The range_starts and range_ends arrays must have the same length';
    END IF;

    WHILE i <= range_length
        DO
            SET start_ip = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(range_starts, ',', i), ',', -1) AS UNSIGNED);
            SET end_ip = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(range_ends, ',', i), ',', -1) AS UNSIGNED);

            IF ip >= start_ip AND ip <= end_ip THEN
                RETURN TRUE;
            END IF;

            SET i = i + 1;
        END WHILE;

    RETURN FALSE;
END $$

DELIMITER ;
