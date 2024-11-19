USE torrent;

START TRANSACTION;


SHOW VARIABLES LIKE "secure_file_priv";

DROP TEMPORARY TABLE IF EXISTS tmp_category;
DROP TEMPORARY TABLE IF EXISTS tmp_resource;
DROP TEMPORARY TABLE IF EXISTS tmp_uploader;
DROP TEMPORARY TABLE IF EXISTS tmp_share;
DROP TEMPORARY TABLE IF EXISTS tmp_film_archetype;
DROP TEMPORARY TABLE IF EXISTS tmp_film_instance;
DROP TEMPORARY TABLE IF EXISTS tmp_music_archetype;
DROP TEMPORARY TABLE IF EXISTS tmp_music_instance;
DROP TEMPORARY TABLE IF EXISTS tmp_game_archetype;
DROP TEMPORARY TABLE IF EXISTS tmp_game_instance;
DROP TEMPORARY TABLE IF EXISTS tmp_book_archetype;
DROP TEMPORARY TABLE IF EXISTS tmp_ebook;
DROP TEMPORARY TABLE IF EXISTS tmp_audio_book;
DROP TEMPORARY TABLE IF EXISTS tmp_book_instance;
DROP TEMPORARY TABLE IF EXISTS tmp_operating_system;


-- Category
CREATE TEMPORARY TABLE tmp_category
(
    name VARCHAR(10) NOT NULL
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/category.csv'
    INTO TABLE tmp_category
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT IGNORE INTO category (name)
SELECT name
from tmp_category;

-- Operating system
CREATE TABLE tmp_operating_system
(
    name VARCHAR(10) UNIQUE PRIMARY KEY
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/operating_system.csv'
    INTO TABLE tmp_operating_system
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT IGNORE INTO operating_system (name)
SELECT name
from tmp_operating_system;

-- Resource
CREATE TEMPORARY TABLE tmp_resource
(
    id            VARCHAR(36),
    upload_time   VARCHAR(36)                        NOT NULL,
    leeches       SMALLINT                           NOT NULL,
    seeders       SMALLINT                           NOT NULL,
    info_sha256   BLOB                               NOT NULL,
    url           TEXT                               NOT NULL,
    is_legal      VARCHAR(1),
    size_in_bytes BIGINT CHECK ( size_in_bytes > 0 ) NOT NULL
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/resource.csv'
    INTO TABLE tmp_resource
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT INTO resource(id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
SELECT UNHEX(REPLACE(id, '-', '')),
       REPLACE(REPLACE(upload_time, 'T', ' '), 'Z', ''),
       leeches,
       seeders,
       info_sha256,
       url,
       (IF(is_legal = 't', TRUE, FALSE)),
       size_in_bytes
FROM tmp_resource;

-- Uploader
CREATE TEMPORARY TABLE tmp_uploader
(
    id               VARCHAR(36),
    name             VARCHAR(50) NOT NULL,
    recently_active  VARCHAR(36) NOT NULL,
    first_logged_in  VARCHAR(36) NOT NULL,
    recently_used_ip VARCHAR(15) NOT NULL,
    first_used_ip    VARCHAR(15) NOT NULL
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/uploader.csv'
    INTO TABLE tmp_uploader
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT INTO uploader(id, name, first_logged_in, recently_active, recently_used_ip, first_used_ip)
SELECT UNHEX(REPLACE(id, '-', '')),
       name,
       REPLACE(REPLACE(first_logged_in, 'T', ' '), 'Z', ''),
       REPLACE(REPLACE(recently_active, 'T', ' '), 'Z', ''),
       INET_ATON(recently_used_ip),
       INET_ATON(first_used_ip)
FROM tmp_uploader;

-- Share
CREATE TEMPORARY TABLE tmp_share
(
    resource_id VARCHAR(36),
    title       VARCHAR(256) NOT NULL,
    description VARCHAR(512),
    uploader_id VARCHAR(36)  NOT NULL,
    category    VARCHAR(10)  NOT NULL
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/share.csv'
    INTO TABLE tmp_share
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT INTO share(resource_id, title, description, uploader_id, category)
SELECT UNHEX(REPLACE(resource_id, '-', '')),
       title,
       description,
       UNHEX(REPLACE(uploader_id, '-', '')),
       category
FROM tmp_share;

-- Film
CREATE TEMPORARY TABLE tmp_film_archetype
(
    id                VARCHAR(36),
    title             VARCHAR(256) NOT NULL,
    format            VARCHAR(256) NOT NULL,
    language_code     VARCHAR(2)   NOT NULL,
    resolution        VARCHAR(9)   NOT NULL,
    release_year      VARCHAR(4)   NOT NULL,
    length_in_minutes SMALLINT     NOT NULL
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/film_archetype.csv'
    INTO TABLE tmp_film_archetype
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT INTO film_archetype(id, title, format, language_code, resolution, release_year, length_in_minutes)
SELECT UNHEX(REPLACE(id, '-', '')),
       title,
       format,
       language_code,
       resolution,
       release_year,
       length_in_minutes
FROM tmp_film_archetype;

CREATE TEMPORARY TABLE tmp_film_instance
(
    share_id     VARCHAR(36),
    archetype_id VARCHAR(36)
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/film_instance.csv'
    INTO TABLE tmp_film_instance
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT INTO film_instance(share_id, archetype_id)
SELECT UNHEX(REPLACE(share_id, '-', '')),
       UNHEX(REPLACE(archetype_id, '-', ''))
FROM tmp_film_instance;

-- Music
CREATE TEMPORARY TABLE tmp_music_archetype
(
    id           VARCHAR(36),
    length_epoch SMALLINT     NOT NULL,
    format       VARCHAR(6)   NOT NULL,
    album_name   VARCHAR(256) NOT NULL,
    release_year VARCHAR(4)
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/music_archetype.csv'
    INTO TABLE tmp_music_archetype
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT INTO music_archetype(id, length_epoch, format, album_name, release_year)
SELECT UNHEX(REPLACE(id, '-', '')),
       length_epoch,
       format,
       album_name,
       release_year
FROM tmp_music_archetype;

CREATE TEMPORARY TABLE tmp_music_instance
(
    share_id     VARCHAR(36),
    archetype_id VARCHAR(36)
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/music_instance.csv'
    INTO TABLE tmp_music_instance
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT INTO music_instance(share_id, archetype_id)
SELECT UNHEX(REPLACE(share_id, '-', '')),
       UNHEX(REPLACE(archetype_id, '-', ''))
FROM tmp_music_instance;

-- Game
CREATE TEMPORARY TABLE tmp_game_archetype
(
    id               VARCHAR(36),
    title            VARCHAR(256) NOT NULL,
    studio           VARCHAR(256) NOT NULL,
    language_code    VARCHAR(2)   NOT NULL,
    release_year     VARCHAR(4)   NOT NULL,
    operating_system VARCHAR(10)  NOT NULL
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/game_archetype.csv'
    INTO TABLE tmp_game_archetype
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT INTO game_archetype(id, title, studio, language_code, release_year, operating_system)
SELECT UNHEX(REPLACE(id, '-', '')),
       title,
       studio,
       language_code,
       release_year,
       operating_system
FROM tmp_game_archetype;

CREATE TEMPORARY TABLE tmp_game_instance
(
    share_id     VARCHAR(36),
    archetype_id VARCHAR(36)
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/game_instance.csv'
    INTO TABLE tmp_game_instance
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT INTO game_instance(share_id, archetype_id)
SELECT UNHEX(REPLACE(share_id, '-', '')),
       UNHEX(REPLACE(archetype_id, '-', ''))
FROM tmp_game_instance;

-- Book
CREATE TEMPORARY TABLE tmp_book_archetype
(
    id            VARCHAR(36),
    title         VARCHAR(256) NOT NULL,
    author        VARCHAR(256) NOT NULL,
    language_code VARCHAR(2)   NOT NULL,
    ISBN          VARCHAR(13)  NOT NULL
);

CREATE TEMPORARY TABLE tmp_audio_book
(
    id             VARCHAR(36),
    studio         VARCHAR(256)                       NOT NULL,
    read_by        VARCHAR(256)                       NOT NULL,
    language_code  VARCHAR(2)                         NOT NULL,
    length_epoch   SMALLINT CHECK ( length_epoch > 0) NOT NULL,
    format         VARCHAR(6)                         NOT NULL,
    release_year   VARCHAR(4)                         NOT NULL,
    source_book_id VARCHAR(36)                        NOT NULL
);

CREATE TEMPORARY TABLE tmp_ebook
(
    id             VARCHAR(36),
    studio         VARCHAR(256) NOT NULL,
    format         VARCHAR(6)   NOT NULL,
    release_year   VARCHAR(4)   NOT NULL,
    source_book_id VARCHAR(36)  NOT NULL
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/book_archetype.csv'
    INTO TABLE tmp_book_archetype
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

LOAD DATA INFILE '/var/lib/mysql-files/dumps/ebook.csv'
    INTO TABLE tmp_ebook
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

LOAD DATA INFILE '/var/lib/mysql-files/dumps/audio_book.csv'
    INTO TABLE tmp_audio_book
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT INTO book_archetype(id, title, author, language_code, ISBN)
SELECT UNHEX(REPLACE(id, '-', '')),
       title,
       author,
       language_code,
       ISBN
FROM tmp_book_archetype;

INSERT INTO ebook(id, studio, format, release_year, source_book_id)
SELECT UNHEX(REPLACE(id, '-', '')),
       studio,
       format,
       release_year,
       UNHEX(REPLACE(source_book_id, '-', ''))
FROM tmp_ebook;

INSERT INTO audio_book(id, studio, read_by, language_code, length_epoch, format, release_year, source_book_id)
SELECT UNHEX(REPLACE(id, '-', '')),
       studio,
       read_by,
       language_code,
       length_epoch,
       format,
       release_year,
       UNHEX(REPLACE(source_book_id, '-', ''))
FROM tmp_audio_book;

CREATE TEMPORARY TABLE tmp_book_instance
(
    share_id     VARCHAR(36),
    archetype_id VARCHAR(36)
);

LOAD DATA INFILE '/var/lib/mysql-files/dumps/book_instance.csv'
    INTO TABLE tmp_book_instance
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;

INSERT INTO book_instance(share_id, archetype_id)
SELECT UNHEX(REPLACE(share_id, '-', '')),
       UNHEX(REPLACE(archetype_id, '-', ''))
FROM tmp_book_instance;

DROP TEMPORARY TABLE IF EXISTS tmp_category;
DROP TEMPORARY TABLE IF EXISTS tmp_resource;
DROP TEMPORARY TABLE IF EXISTS tmp_uploader;
DROP TEMPORARY TABLE IF EXISTS tmp_share;
DROP TEMPORARY TABLE IF EXISTS tmp_film_archetype;
DROP TEMPORARY TABLE IF EXISTS tmp_film_instance;
DROP TEMPORARY TABLE IF EXISTS tmp_music_archetype;
DROP TEMPORARY TABLE IF EXISTS tmp_music_instance;
DROP TEMPORARY TABLE IF EXISTS tmp_game_archetype;
DROP TEMPORARY TABLE IF EXISTS tmp_game_instance;
DROP TEMPORARY TABLE IF EXISTS tmp_book_archetype;
DROP TEMPORARY TABLE IF EXISTS tmp_ebook;
DROP TEMPORARY TABLE IF EXISTS tmp_audio_book;
DROP TEMPORARY TABLE IF EXISTS tmp_book_instance;
DROP TEMPORARY TABLE IF EXISTS tmp_operating_system;

COMMIT;


DELIMITER ;




