CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS btree_gin;


DROP SCHEMA IF EXISTS torrent CASCADE;
DROP USER IF EXISTS contributor;
DROP USER IF EXISTS torrent_admin;

CREATE SCHEMA torrent

    CREATE TABLE category
    (
        name VARCHAR(10) PRIMARY KEY NOT NULL
    )

    CREATE TABLE resource
    (
        id            UUID PRIMARY KEY,
        upload_time   TIMESTAMP                       NOT NULL,
        leeches       SMALLINT CHECK ( leeches >= 0 ) NOT NULL,
        seeders       SMALLINT CHECK ( seeders >= 0 ) NOT NULL,
        info_sha256   BYTEA                           NOT NULL,
        url           TEXT UNIQUE                     NOT NULL,
        is_legal      BOOLEAN,
        size_in_bytes BIGINT CHECK (size_in_bytes > 0)
    )

    CREATE TABLE uploader
    (
        id               UUID PRIMARY KEY,
        name             VARCHAR(50) UNIQUE NOT NULL,
        recently_active  TIMESTAMP          NOT NULL,
        first_logged_in  TIMESTAMP          NOT NULL,
        recently_used_ip INET               NOT NULL,
        first_used_ip    INET               NOT NULL
    )

    CREATE TABLE share
    (
        resource_id UUID PRIMARY KEY REFERENCES resource,
        title       VARCHAR(256)                           NOT NULL,
        description VARCHAR(512),
        uploader_id UUID                                   NOT NULL REFERENCES uploader,
        category    VARCHAR(10) REFERENCES category (name) NOT NULL
    )

    CREATE TABLE film_archetype
    (
        id                UUID PRIMARY KEY,
        title             VARCHAR(256)                             NOT NULL,
        format            VARCHAR(256)                             NOT NULL,
        language_code     VARCHAR(2)                               NOT NULL,
        resolution        VARCHAR(9)                               NOT NULL,
        release_year      VARCHAR(4)                               NOT NULL,
        length_in_minutes SMALLINT CHECK ( length_in_minutes > 0 ) NOT NULL
    )

    CREATE TABLE film_instance
    (
        share_id     UUID PRIMARY KEY REFERENCES share,
        archetype_id UUID REFERENCES film_archetype
    )

    CREATE TABLE music_archetype
    (
        id           UUID PRIMARY KEY,
        length_epoch SMALLINT CHECK ( length_epoch > 0 ) NOT NULL,
        format       VARCHAR(6)                          NOT NULL,
        album_name   VARCHAR(256)                        NOT NULL,
        release_year VARCHAR(4)
    )

    CREATE TABLE music_instance
    (
        share_id     UUID PRIMARY KEY REFERENCES share,
        archetype_id UUID REFERENCES music_archetype
    )

    CREATE TABLE operating_system
    (
        name VARCHAR(10) UNIQUE PRIMARY KEY
    )

    CREATE TABLE game_archetype
    (
        id               UUID PRIMARY KEY,
        title            VARCHAR(256)                            NOT NULL,
        studio           VARCHAR(256)                            NOT NULL,
        language_code    VARCHAR(2)                              NOT NULL,
        release_year     VARCHAR(4)                              NOT NULL,
        operating_system VARCHAR(10) REFERENCES operating_system NOT NULL
    )

    CREATE TABLE game_instance
    (
        share_id     UUID PRIMARY KEY REFERENCES share,
        archetype_id UUID REFERENCES game_archetype
    )

    CREATE TABLE book_archetype
    (
        id            UUID PRIMARY KEY,
        title         VARCHAR(256) NOT NULL,
        author        VARCHAR(256) NOT NULL,
        language_code VARCHAR(2)   NOT NULL,
        ISBN          VARCHAR(13)  NOT NULL
    )

    CREATE TABLE audio_book
    (
        id             UUID PRIMARY KEY,
        studio         VARCHAR(256)                        NOT NULL,
        read_by        VARCHAR(256)                        NOT NULL,
        language_code  VARCHAR(2)                          NOT NULL,
        length_epoch   SMALLINT CHECK ( length_epoch > 0 ) NOT NULL,
        format         VARCHAR(6)                          NOT NULL,
        release_year   VARCHAR(4)                          NOT NULL,
        source_book_id UUID REFERENCES book_archetype (id) NOT NULL
    )

    CREATE TABLE ebook
    (
        id             UUID PRIMARY KEY,
        studio         VARCHAR(256)                        NOT NULL,
        format         VARCHAR(6)                          NOT NULL,
        release_year   VARCHAR(4)                          NOT NULL,
        source_book_id UUID REFERENCES book_archetype (id) NOT NULL

    )

    CREATE TABLE book_instance
    (
        share_id     UUID PRIMARY KEY REFERENCES share,
        archetype_id UUID REFERENCES book_archetype
    )


    CREATE INDEX sd on share (description  varchar_pattern_ops)

    CREATE INDEX st on share (title varchar_pattern_ops)

    CREATE INDEX url_index ON resource (url text_pattern_ops)

    CREATE INDEX ftitle ON film_archetype (title varchar_pattern_ops)

    CREATE INDEX gtitle ON game_archetype (title varchar_pattern_ops)

    CREATE INDEX btitle ON book_archetype (title varchar_pattern_ops)

    CREATE INDEX bau ON book_archetype (author varchar_pattern_ops)

    CREATE INDEX abr ON audio_book (read_by varchar_pattern_ops)

    CREATE INDEX ip on uploader using GIST (recently_used_ip, first_used_ip)
;

INSERT INTO torrent.operating_system (name)
VALUES ('Windows 10');
INSERT INTO torrent.operating_system (name)
VALUES ('SteamOs');
INSERT INTO torrent.operating_system (name)
VALUES ('Windows 11');
INSERT INTO torrent.operating_system (name)
VALUES ('Linux');
INSERT INTO torrent.operating_system (name)
VALUES ('OSX');

INSERT INTO torrent.category (name)
VALUES ('film');
INSERT INTO torrent.category (name)
VALUES ('ebook');
INSERT INTO torrent.category (name)
VALUES ('audiobook');
INSERT INTO torrent.category (name)
VALUES ('music');
INSERT INTO torrent.category (name)
VALUES ('game');

CREATE USER contributor;
CREATE USER torrent_admin PASSWORD 'passwd';

-- Views

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
SELECT s.title,
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
SELECT COUNT(first_used_ip) FROM all_ips_by_user WHERE first_used_ip << '100.43.72.1/24';

ALTER SCHEMA torrent OWNER TO torrent_admin;
GRANT SELECT ON share_movie_details TO contributor;

-- Function
CREATE OR REPLACE FUNCTION is_ip_in_ranges(ip_address INET, range_starts INET[], range_ends INET[])
    RETURNS BOOLEAN AS
$$
DECLARE
    i INT;
BEGIN

    IF array_length(range_starts, 1) <> array_length(range_ends, 1) THEN
        RAISE EXCEPTION 'The range_starts and range_ends arrays must have the same length';
    END IF;

    FOR i IN 1 .. array_length(range_starts, 1)
        LOOP
            IF ip_address >= range_starts[i] AND ip_address <= range_ends[i] THEN
                RETURN TRUE;
            END IF;
        END LOOP;


    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Alterations
ALTER TABLE torrent.share
    DROP CONSTRAINT share_resource_id_fkey,
    ADD CONSTRAINT share_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES torrent.resource (id) ON DELETE CASCADE;

ALTER TABLE torrent.game_instance
    DROP CONSTRAINT game_instance_share_id_fkey,
    ADD CONSTRAINT game_instance_share_id_fkey FOREIGN KEY (share_id) REFERENCES torrent.share (resource_id) ON DELETE CASCADE;

ALTER TABLE torrent.film_instance
    DROP CONSTRAINT film_instance_share_id_fkey,
    ADD CONSTRAINT film_instance_share_id_fkey FOREIGN KEY (share_id) REFERENCES torrent.share (resource_id) ON DELETE CASCADE;

ALTER TABLE torrent.book_instance
    DROP CONSTRAINT book_instance_share_id_fkey,
    ADD CONSTRAINT book_instance_share_id_fkey FOREIGN KEY (share_id) REFERENCES torrent.share (resource_id) ON DELETE CASCADE;

ALTER TABLE torrent.music_instance
    DROP CONSTRAINT music_instance_share_id_fkey,
    ADD CONSTRAINT music_instance_share_id_fkey FOREIGN KEY (share_id) REFERENCES torrent.share (resource_id) ON DELETE CASCADE;
