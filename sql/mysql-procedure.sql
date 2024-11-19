USE torrent;

DROP TRIGGER IF EXISTS cleanup_resource;
CREATE TRIGGER cleanup_resource
    AFTER DELETE
    ON torrent.share
    FOR EACH ROW
BEGIN
    IF @trigger_flag IS NULL THEN
        SET @trigger_flag = 1;
    END IF;
    DELETE FROM torrent.resource WHERE id = OLD.resource_id;

    IF (SELECT COUNT(*) FROM torrent.game_instance WHERE share_id = OLD.resource_id) > 0 THEN
        DELETE FROM torrent.game_instance WHERE share_id = OLD.resource_id;
    END IF;

    IF (SELECT COUNT(*) FROM torrent.film_instance WHERE share_id = OLD.resource_id) > 0 THEN
        DELETE FROM torrent.film_instance WHERE share_id = OLD.resource_id;
    END IF;

    IF (SELECT COUNT(*) FROM torrent.book_instance WHERE share_id = OLD.resource_id) > 0 THEN
        DELETE FROM torrent.book_instance WHERE share_id = OLD.resource_id;
    END IF;

    IF (SELECT COUNT(*) FROM torrent.music_instance WHERE share_id = OLD.resource_id) > 0 THEN
        DELETE FROM torrent.music_instance WHERE share_id = OLD.resource_id;
    END IF;
END;

DROP PROCEDURE IF EXISTS cleanup_share_procedure;
CREATE PROCEDURE cleanup_share_procedure(IN old_id BINARY(16))
BEGIN
    IF @trigger_flag IS NULL THEN
        SET @trigger_flag = 1;
    END IF;
    DELETE FROM torrent.share WHERE resource_id = old_id;

    DELETE FROM torrent.game_instance WHERE share_id = old_id;
    DELETE FROM torrent.film_instance WHERE share_id = old_id;
    DELETE FROM torrent.book_instance WHERE share_id = old_id;
    DELETE FROM torrent.music_instance WHERE share_id = old_id;
END;

DROP TRIGGER IF EXISTS cleanup_share_trigger;
CREATE TRIGGER cleanup_share_trigger
    BEFORE DELETE
    ON torrent.resource
    FOR EACH ROW
BEGIN

    CALL cleanup_share_procedure(OLD.id);
END;

DROP PROCEDURE IF EXISTS insert_operating_system;
CREATE PROCEDURE insert_operating_system(IN new_os VARCHAR(10))
BEGIN
    IF @trigger_flag IS NULL THEN
        SET @trigger_flag = 1;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM torrent.operating_system WHERE name = new_os) THEN
        INSERT INTO torrent.operating_system (name) VALUES (new_os);
    END IF;
END;

DROP TRIGGER IF EXISTS update_games_os;
CREATE TRIGGER update_games_os
    AFTER INSERT
    ON torrent.game_archetype
    FOR EACH ROW
BEGIN
    CALL insert_operating_system(NEW.operating_system);
END;

DROP PROCEDURE IF EXISTS add_game;
CREATE PROCEDURE add_game(
    IN p_title VARCHAR(256),
    IN p_game_archetype_id BINARY(16),
    IN p_uploader_id BINARY(16),
    IN file_sha BLOB,
    IN p_url TEXT,
    IN p_recent_uploader_ip BIGINT,
    IN p_description VARCHAR(512),
    IN p_size_in_bytes BIGINT,
    IN p_is_legal BOOLEAN
)
BEGIN
    DECLARE resource_uuid BINARY(16) DEFAULT UNHEX(REPLACE(UUID(), '-', ''));
    DECLARE inserted_into_category VARCHAR(10) DEFAULT 'game';
    DECLARE now_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            SIGNAL SQLSTATE '45000';
        END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM torrent.uploader WHERE id = p_uploader_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Uploader does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM torrent.game_archetype WHERE id = p_game_archetype_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Game archetype does not exist';
    END IF;

    IF EXISTS (SELECT 1 FROM torrent.resource WHERE url = p_url) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Resource URL already exists';
    END IF;

    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    VALUES (resource_uuid, now_ts, 0, 0, file_sha, p_url, p_is_legal, p_size_in_bytes);

    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    VALUES (resource_uuid, p_title, p_description, p_uploader_id, inserted_into_category);

    INSERT INTO torrent.game_instance (share_id, archetype_id)
    VALUES (resource_uuid, p_game_archetype_id);

    UPDATE torrent.uploader
    SET recently_used_ip = p_recent_uploader_ip,
        recently_active  = now_ts
    WHERE id = p_uploader_id;
    COMMIT;
END;

DROP PROCEDURE IF EXISTS add_ebook;
CREATE PROCEDURE add_ebook(
    IN p_title VARCHAR(256),
    IN p_book_archetype BINARY(16),
    IN p_ebook BINARY(16),
    IN p_uploader_id BINARY(16),
    IN file_sha BLOB,
    IN p_url TEXT,
    IN p_recent_uploader_ip BIGINT,
    IN p_description VARCHAR(512),
    IN p_size_in_bytes BIGINT,
    IN p_is_legal BOOLEAN
)
BEGIN
    DECLARE resource_uuid CHAR(36) DEFAULT UUID();
    DECLARE inserted_into_category VARCHAR(10) DEFAULT 'ebook';
    DECLARE now_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An unexpected error occurred';
        END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM torrent.uploader WHERE id = p_uploader_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Uploader does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM torrent.book_archetype WHERE id = p_book_archetype) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Book archetype does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM torrent.ebook WHERE id = p_ebook) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'eBook does not exist';
    END IF;

    IF EXISTS (SELECT 1 FROM torrent.resource WHERE url = p_url) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Resource URL already exists';
    END IF;

    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    VALUES (resource_uuid, now_ts, 0, 0, file_sha, p_url, p_is_legal, p_size_in_bytes);

    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    VALUES (resource_uuid, p_title, p_description, p_uploader_id, inserted_into_category);

    INSERT INTO torrent.book_instance (share_id, archetype_id)
    VALUES (resource_uuid, p_book_archetype);

    UPDATE torrent.uploader
    SET recently_used_ip = p_recent_uploader_ip,
        recently_active  = now_ts
    WHERE id = p_uploader_id;
    COMMIT;
END;

DROP PROCEDURE IF EXISTS add_audiobook;
CREATE PROCEDURE add_audiobook(
    IN p_title VARCHAR(256),
    IN p_book_archetype BINARY(16),
    IN p_audio_book BINARY(16),
    IN p_uploader_id BINARY(16),
    IN file_sha BLOB,
    IN p_url TEXT,
    IN p_recent_uploader_ip BIGINT,
    IN p_description VARCHAR(512),
    IN p_size_in_bytes BIGINT,
    IN p_is_legal BOOLEAN
)
BEGIN
    DECLARE resource_uuid CHAR(36) DEFAULT UUID();
    DECLARE inserted_into_category VARCHAR(10) DEFAULT 'audiobook';
    DECLARE now_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An unexpected error occurred';
        END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM torrent.uploader WHERE id = p_uploader_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Uploader does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM torrent.book_archetype WHERE id = p_book_archetype) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Book archetype does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM torrent.audio_book WHERE id = p_audio_book) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audio book does not exist';
    END IF;

    IF EXISTS (SELECT 1 FROM torrent.resource WHERE url = p_url) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Resource URL already exists';
    END IF;

    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    VALUES (resource_uuid, now_ts, 0, 0, file_sha, p_url, p_is_legal, p_size_in_bytes);

    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    VALUES (resource_uuid, p_title, p_description, p_uploader_id, inserted_into_category);

    INSERT INTO torrent.book_instance (share_id, archetype_id)
    VALUES (resource_uuid, p_book_archetype);

    UPDATE torrent.uploader
    SET recently_used_ip = p_recent_uploader_ip,
        recently_active  = now_ts
    WHERE id = p_uploader_id;
    COMMIT;
END;

DROP PROCEDURE IF EXISTS add_music;
CREATE PROCEDURE add_music(
    IN p_title VARCHAR(256),
    IN p_music_archetype BINARY(16),
    IN p_uploader_id BINARY(16),
    IN file_sha BLOB,
    IN p_url TEXT,
    IN p_recent_uploader_ip BIGINT,
    IN p_description VARCHAR(512),
    IN p_size_in_bytes BIGINT,
    IN p_is_legal BOOLEAN
)
BEGIN
    DECLARE resource_uuid CHAR(36) DEFAULT UUID();
    DECLARE inserted_into_category VARCHAR(10) DEFAULT 'music';
    DECLARE now_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An unexpected error occurred';
        END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM torrent.uploader WHERE id = p_uploader_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Uploader does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM torrent.music_archetype WHERE id = p_music_archetype) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Music archetype does not exist';
    END IF;

    IF EXISTS (SELECT 1 FROM torrent.resource WHERE url = p_url) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Resource URL already exists';
    END IF;

    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    VALUES (resource_uuid, now_ts, 0, 0, file_sha, p_url, p_is_legal, p_size_in_bytes);

    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    VALUES (resource_uuid, p_title, p_description, p_uploader_id, inserted_into_category);

    INSERT INTO torrent.music_instance (share_id, archetype_id)
    VALUES (resource_uuid, p_music_archetype);

    UPDATE torrent.uploader
    SET recently_used_ip = p_recent_uploader_ip,
        recently_active  = now_ts
    WHERE id = p_uploader_id;
    COMMIT;
END;

DROP PROCEDURE IF EXISTS add_film;
CREATE PROCEDURE add_film(
    IN p_title VARCHAR(256),
    IN p_film_archetype BINARY(16),
    IN p_uploader_id BINARY(16),
    IN file_sha BLOB,
    IN p_url TEXT,
    IN p_recent_uploader_ip BIGINT,
    IN p_description VARCHAR(512),
    IN p_size_in_bytes BIGINT,
    IN p_is_legal BOOLEAN
)
BEGIN
    DECLARE resource_uuid CHAR(36) DEFAULT UUID();
    DECLARE inserted_into_category VARCHAR(10) DEFAULT 'film';
    DECLARE now_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An unexpected error occurred';
        END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM torrent.uploader WHERE id = p_uploader_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Uploader does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM torrent.film_archetype WHERE id = p_film_archetype) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Film archetype does not exist';
    END IF;

    IF EXISTS (SELECT 1 FROM torrent.resource WHERE url = p_url) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Resource URL already exists';
    END IF;

    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    VALUES (resource_uuid, now_ts, 0, 0, file_sha, p_url, p_is_legal, p_size_in_bytes);

    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    VALUES (resource_uuid, p_title, p_description, p_uploader_id, inserted_into_category);

    INSERT INTO torrent.film_instance (share_id, archetype_id)
    VALUES (resource_uuid, p_film_archetype);

    UPDATE torrent.uploader
    SET recently_used_ip = p_recent_uploader_ip,
        recently_active  = now_ts
    WHERE id = p_uploader_id;
    COMMIT;
END;

DROP PROCEDURE IF EXISTS add_game_archetype;
CREATE PROCEDURE add_game_archetype(
    IN p_title VARCHAR(256),
    IN p_studio VARCHAR(256),
    IN p_language_code VARCHAR(2),
    IN p_release_year VARCHAR(4),
    IN p_os VARCHAR(10)
)
BEGIN
    DECLARE archetype_uuid CHAR(36) DEFAULT UUID();

    IF EXISTS (SELECT 1
               FROM torrent.game_archetype
               WHERE title = p_title
                 AND studio = p_studio
                 AND language_code = p_language_code
                 AND release_year = p_release_year
                 AND operating_system = p_os) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Archetype with identical attributes already exists';
    END IF;

    INSERT INTO torrent.game_archetype (id, title, studio, language_code, release_year, operating_system)
    VALUES (archetype_uuid, p_title, p_studio, p_language_code, p_release_year, p_os);
END;

DROP PROCEDURE IF EXISTS add_book_archetype;
CREATE PROCEDURE add_book_archetype(
    IN p_title VARCHAR(256),
    IN p_author VARCHAR(256),
    IN p_language_code VARCHAR(2),
    IN p_ISBN VARCHAR(13)
)
BEGIN
    DECLARE archetype_uuid CHAR(36) DEFAULT UUID();

    IF EXISTS (SELECT 1
               FROM torrent.book_archetype
               WHERE title = p_title
                 AND author = p_author
                 AND language_code = p_language_code
                 AND isbn = p_ISBN) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Archetype with identical attributes already exists';
    END IF;

    INSERT INTO torrent.book_archetype (id, title, author, language_code, isbn)
    VALUES (archetype_uuid, p_title, p_author, p_language_code, p_ISBN);
END;

DROP PROCEDURE IF EXISTS add_ebook_archetype;
CREATE PROCEDURE add_ebook_archetype(
    IN p_studio VARCHAR(256),
    IN p_format VARCHAR(256),
    IN p_release_year VARCHAR(4),
    IN p_archetype_id BINARY(16)
)
BEGIN
    DECLARE ebook_uuid CHAR(36) DEFAULT UUID();

    IF EXISTS (SELECT 1
               FROM torrent.ebook
               WHERE studio = p_studio
                 AND format = p_format
                 AND release_year = p_release_year
                 AND source_book_id = p_archetype_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Archetype with identical attributes already exists';
    END IF;

    INSERT INTO torrent.ebook (id, studio, format, release_year, source_book_id)
    VALUES (ebook_uuid, p_studio, p_format, p_release_year, p_archetype_id);
END;

DROP PROCEDURE IF EXISTS add_ebook_archetype;
CREATE PROCEDURE add_ebook_archetype(
    IN p_title VARCHAR(256),
    IN p_author VARCHAR(256),
    IN p_language_code VARCHAR(2),
    IN p_ISBN VARCHAR(13),
    IN p_studio VARCHAR(256),
    IN p_format VARCHAR(256),
    IN p_release_year VARCHAR(4)
)
BEGIN
    DECLARE archetype_uuid CHAR(36) DEFAULT UUID();
    DECLARE ebook_uuid CHAR(36) DEFAULT UUID();

    IF EXISTS (SELECT 1
               FROM torrent.book_archetype
               WHERE title = p_title
                 AND author = p_author
                 AND language_code = p_language_code
                 AND isbn = p_ISBN) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Book archetype with identical attributes already exists';
    END IF;

    INSERT INTO torrent.book_archetype (id, title, author, language_code, isbn)
    VALUES (archetype_uuid, p_title, p_author, p_language_code, p_ISBN);

    IF EXISTS (SELECT 1
               FROM torrent.ebook
               WHERE studio = p_studio
                 AND format = p_format
                 AND release_year = p_release_year
                 AND source_book_id = archetype_uuid) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ebook with identical attributes already exists';
    END IF;

    INSERT INTO torrent.ebook (id, studio, format, release_year, source_book_id)
    VALUES (ebook_uuid, p_studio, p_format, p_release_year, archetype_uuid);
END;
