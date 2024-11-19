CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE PROCEDURE add_game(p_title varchar(256), p_game_archetype_id uuid, p_uploader_id uuid, file_sha bytea,
                                     p_url text,
                                     p_recent_uploader_ip inet,
                                     p_description varchar(512) default null,
                                     p_size_in_bytes BIGINT default 0,
                                     p_is_legal boolean default false)
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
DECLARE
    resource_uuid          UUID      := gen_random_uuid();
    inserted_into_category VARCHAR   := 'game';
    now_ts                 TIMESTAMP := now();
BEGIN
    -- Check if archetype and uploader actually exists
    IF NOT EXISTS (SELECT 1 FROM torrent.uploader u WHERE u.id = p_uploader_id) THEN
        RAISE NOTICE 'Serious user data violation! A NON EXISTENT uploader by the id(%) tried an upload to resource(%).',p_uploader_id,p_url;
        RETURN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM torrent.game_archetype ga WHERE ga.id = p_game_archetype_id) THEN
        RAISE NOTICE 'Game archetype by the id(%) does not exist.',p_game_archetype_id;
        RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM torrent.resource r WHERE r.url = p_url) THEN
        RAISE NOTICE 'Resource URL already pointing at something else %.',p_url;
        RETURN;
    END IF;

    -- Resource
    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    values (resource_uuid, now_ts, 0, 0, file_sha, p_url, p_is_legal, p_size_in_bytes);
    -- Share
    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    values (resource_uuid, p_title, p_description, p_uploader_id, inserted_into_category);
    -- Connect them and the archetype through an instance
    INSERT INTO torrent.game_instance (share_id, archetype_id) VALUES (resource_uuid, p_game_archetype_id);
    -- Update last active for uploader
    UPDATE torrent.uploader
    SET (recently_used_ip, recently_active) = (p_recent_uploader_ip, now_ts)
    WHERE id = p_uploader_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Resource uuid already exists %.', resource_uuid;
        ROLLBACK;
    -- Absolute worst case scenario with foreign keys
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Either one of foreign keys does not exist and no previous errors were raised: game_archetype(%), uploader_id(%)', p_game_archetype_id, p_uploader_id;
        ROLLBACK;
    WHEN OTHERS THEN
        RAISE NOTICE 'An unexpected error occurred: %', SQLERRM;
        ROLLBACK;
END;
    -- Add ebook
$$;
CREATE OR REPLACE PROCEDURE add_ebook(p_title varchar(256), p_book_archetype uuid, p_ebook uuid, p_uploader_id uuid,
                                      file_sha bytea,
                                      p_url text,
                                      p_recent_uploader_ip inet,
                                      p_description varchar(512) default null,
                                      p_size_in_bytes BIGINT default 0,
                                      p_is_legal boolean default false)
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
DECLARE
    resource_uuid          UUID      := gen_random_uuid();
    inserted_into_category VARCHAR   := 'ebook';
    now_ts                 TIMESTAMP := now();
BEGIN
    -- Check if archetype and uploader actually exists
    IF NOT EXISTS (SELECT 1 FROM torrent.uploader u WHERE u.id = p_uploader_id) THEN
        RAISE NOTICE 'Serious user data violation! A NON EXISTENT uploader by the id(%) tried an upload to resource(%).',p_uploader_id,p_url;
        RETURN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM torrent.book_archetype ba WHERE ba.id = p_book_archetype) THEN
        RAISE NOTICE 'Game archetype by the id(%) does not exist.',p_book_archetype;
        RETURN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM torrent.ebook eb WHERE eb.id = p_ebook) THEN
        RAISE NOTICE 'Game archetype by the id(%) does not exist.',p_ebook;
        RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM torrent.resource r WHERE r.url = p_url) THEN
        RAISE NOTICE 'Resource URL already pointing at something else %.',p_url;
        RETURN;
    END IF;

    -- Resource
    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    values (resource_uuid, now_ts, 0, 0, file_sha, p_url, p_is_legal, p_size_in_bytes);
    -- Share
    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    values (resource_uuid, p_title, p_description, p_uploader_id, inserted_into_category);
    -- Connect them and the archetype through an instance
    INSERT INTO torrent.book_instance (share_id, archetype_id) VALUES (resource_uuid, p_book_archetype);
    -- Update last active for uploader
    UPDATE torrent.uploader
    SET (recently_used_ip, recently_active) = (p_recent_uploader_ip, now_ts)
    WHERE id = p_uploader_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Resource uuid already exists %.', resource_uuid;
        ROLLBACK;
    -- Absolute worst case scenario with foreign keys
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Either one of foreign keys does not exist and no previous errors were raised: game_archetype(%), uploader_id(%)', p_book_archetype, p_uploader_id;
        ROLLBACK;
    WHEN OTHERS THEN
        RAISE NOTICE 'An unexpected error occurred: %', SQLERRM;
        ROLLBACK;
END;
$$;
CREATE OR REPLACE PROCEDURE add_audiobook(p_title varchar(256), p_book_archetype uuid, p_audio_book uuid,
                                          p_uploader_id uuid,
                                          file_sha bytea,
                                          p_url text,
                                          p_recent_uploader_ip inet,
                                          p_description varchar(512) default null,
                                          p_size_in_bytes BIGINT default 0,
                                          p_is_legal boolean default false)
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
DECLARE
    resource_uuid          UUID      := gen_random_uuid();
    inserted_into_category VARCHAR   := 'audiobook';
    now_ts                 TIMESTAMP := now();
BEGIN
    -- Check if archetype and uploader actually exists
    IF NOT EXISTS (SELECT 1 FROM torrent.uploader u WHERE u.id = p_uploader_id) THEN
        RAISE NOTICE 'Serious user data violation! A NON EXISTENT uploader by the id(%) tried an upload to resource(%).',p_uploader_id,p_url;
        RETURN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM torrent.book_archetype ba WHERE ba.id = p_book_archetype) THEN
        RAISE NOTICE 'Game archetype by the id(%) does not exist.',p_book_archetype;
        RETURN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM torrent.audio_book ab WHERE ab.id = p_audio_book) THEN
        RAISE NOTICE 'Game archetype by the id(%) does not exist.',p_audio_book;
        RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM torrent.resource r WHERE r.url = p_url) THEN
        RAISE NOTICE 'Resource URL already pointing at something else %.',p_url;
        RETURN;
    END IF;

    -- Resource
    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    values (resource_uuid, now_ts, 0, 0, file_sha, p_url, p_is_legal, p_size_in_bytes);
    -- Share
    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    values (resource_uuid, p_title, p_description, p_uploader_id, inserted_into_category);
    -- Connect them and the archetype through an instance
    INSERT INTO torrent.book_instance (share_id, archetype_id) VALUES (resource_uuid, p_book_archetype);
    -- Update last active for uploader
    UPDATE torrent.uploader
    SET (recently_used_ip, recently_active) = (p_recent_uploader_ip, now_ts)
    WHERE id = p_uploader_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Resource uuid already exists %.', resource_uuid;
        ROLLBACK;
    -- Absolute worst case scenario with foreign keys
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Either one of foreign keys does not exist and no previous errors were raised: book_archetype(%), uploader_id(%)', p_book_archetype, p_uploader_id;
        ROLLBACK;
    WHEN OTHERS THEN
        RAISE NOTICE 'An unexpected error occurred: %', SQLERRM;
        ROLLBACK;
END;
$$;
CREATE OR REPLACE PROCEDURE add_music(p_title varchar(256), p_music_archetype uuid, p_uploader_id uuid,
                                      file_sha bytea,
                                      p_url text,
                                      p_recent_uploader_ip inet,
                                      p_description varchar(512) default null,
                                      p_size_in_bytes BIGINT default 0,
                                      p_is_legal boolean default false)
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
DECLARE
    resource_uuid          UUID      := gen_random_uuid();
    inserted_into_category VARCHAR   := 'music';
    now_ts                 TIMESTAMP := now();
BEGIN
    -- Check if archetype and uploader actually exists
    IF NOT EXISTS (SELECT 1 FROM torrent.uploader u WHERE u.id = p_uploader_id) THEN
        RAISE NOTICE 'Serious user data violation! A NON EXISTENT uploader by the id(%) tried an upload to resource(%).',p_uploader_id,p_url;
        RETURN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM torrent.music_archetype ma WHERE ma.id = p_music_archetype) THEN
        RAISE NOTICE 'Game archetype by the id(%) does not exist.',p_music_archetype;
        RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM torrent.resource r WHERE r.url = p_url) THEN
        RAISE NOTICE 'Resource URL already pointing at something else %.',p_url;
        RETURN;
    END IF;

    -- Resource
    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    values (resource_uuid, now_ts, 0, 0, file_sha, p_url, p_is_legal, p_size_in_bytes);
    -- Share
    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    values (resource_uuid, p_title, p_description, p_uploader_id, inserted_into_category);
    -- Connect them and the archetype through an instance
    INSERT INTO torrent.music_instance (share_id, archetype_id) VALUES (resource_uuid, p_music_archetype);
    -- Update last active for uploader
    UPDATE torrent.uploader
    SET (recently_used_ip, recently_active) = (p_recent_uploader_ip, now_ts)
    WHERE id = p_uploader_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Resource uuid already exists %.', resource_uuid;
        ROLLBACK;
    -- Absolute worst case scenario with foreign keys
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Either one of foreign keys does not exist and no previous errors were raised: music_archetype(%), uploader_id(%)', p_music_archetype, p_uploader_id;
        ROLLBACK;
    WHEN OTHERS THEN
        RAISE NOTICE 'An unexpected error occurred: %', SQLERRM;
        ROLLBACK;
END;
$$;
CREATE OR REPLACE PROCEDURE add_film(p_title varchar(256), p_film_archetype uuid, p_uploader_id uuid,
                                     file_sha bytea,
                                     p_url text,
                                     p_recent_uploader_ip inet,
                                     p_description varchar(512) default null,
                                     p_size_in_bytes BIGINT default 0,
                                     p_is_legal boolean default false)
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
DECLARE
    resource_uuid          UUID      := gen_random_uuid();
    inserted_into_category VARCHAR   := 'film';
    now_ts                 TIMESTAMP := now();
BEGIN
    -- Check if archetype and uploader actually exists
    IF NOT EXISTS (SELECT 1 FROM torrent.uploader u WHERE u.id = p_uploader_id) THEN
        RAISE NOTICE 'Serious user data violation! A NON EXISTENT uploader by the id(%) tried an upload to resource(%).',p_uploader_id,p_url;
        RETURN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM torrent.film_archetype fa WHERE fa.id = p_film_archetype) THEN
        RAISE NOTICE 'Film archetype by the id(%) does not exist.',p_film_archetype;
        RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM torrent.resource r WHERE r.url = p_url) THEN
        RAISE NOTICE 'Resource URL already pointing at something else %.',p_url;
        RETURN;
    END IF;

    -- Resource
    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    values (resource_uuid, now_ts, 0, 0, file_sha, p_url, p_is_legal, p_size_in_bytes);
    -- Share
    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    values (resource_uuid, p_title, p_description, p_uploader_id, inserted_into_category);
    -- Connect them and the archetype through an instance
    INSERT INTO torrent.film_instance (share_id, archetype_id) VALUES (resource_uuid, p_film_archetype);
    -- Update last active for uploader
    UPDATE torrent.uploader
    SET (recently_used_ip, recently_active) = (p_recent_uploader_ip, now_ts)
    WHERE id = p_uploader_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Resource uuid already exists %.', resource_uuid;
        ROLLBACK;
    -- Absolute worst case scenario with foreign keys
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Either one of foreign keys does not exist and no previous errors were raised: film_archetype(%), uploader_id(%)', p_film_archetype, p_uploader_id;
        ROLLBACK;
    WHEN OTHERS THEN
        RAISE NOTICE 'An unexpected error occurred: %', SQLERRM;
        ROLLBACK;
END;
$$;

CREATE OR REPLACE PROCEDURE add_game_archetype(p_title varchar(256), p_studio varchar(256), p_language_code varchar(2),
                                               p_release_year varchar(4), p_os varchar(10))
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
DECLARE
    archetype_uuid UUID := gen_random_uuid();
BEGIN
    IF EXISTS (SELECT 1
               FROM torrent.game_archetype ga
               WHERE ga.title = p_title
                 AND ga.studio = p_studio
                 AND ga.language_code = p_language_code
                 AND ga.release_year = p_release_year
                 AND ga.operating_system = p_os) THEN
        RAISE NOTICE 'Archetype with identical attributes already exists';
        RETURN;
    END IF;
    INSERT INTO torrent.game_archetype (id, title, studio, language_code, release_year, operating_system)
    VALUES (archetype_uuid, p_title, p_studio, p_language_code, p_release_year, p_os);
END;
$$;

CREATE OR REPLACE PROCEDURE add_book_archetype(p_title varchar(256), p_author varchar(256), p_language_code varchar(2),
                                               p_ISBN varchar(13))
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
DECLARE
    archetype_uuid UUID := gen_random_uuid();
BEGIN
    IF EXISTS (SELECT 1
               FROM torrent.book_archetype ba
               WHERE ba.title = p_title
                 AND ba.author = p_author
                 AND ba.language_code = p_language_code
                 AND ba.isbn = p_ISBN) THEN
        RAISE NOTICE 'Archetype with identical attributes already exists';
        RETURN;
    END IF;
    INSERT INTO torrent.book_archetype (id, title, author, language_code, isbn)
    VALUES (archetype_uuid, p_title, p_author, p_language_code, p_ISBN);
END;
$$;

CREATE OR REPLACE PROCEDURE add_ebook_archetype(p_studio varchar(256), p_format varchar(256), p_release_year varchar(4),
                                                p_archetype_id uuid)
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
DECLARE
    ebook_uuid UUID := gen_random_uuid();
BEGIN
    IF EXISTS (SELECT 1
               FROM torrent.ebook ea
               WHERE ea.studio = p_studio
                 AND ea.format = p_format
                 AND ea.release_year = p_release_year
                 AND ea.source_book_id = p_archetype_id) THEN
        RAISE NOTICE 'Archetype with identical attributes already exists';
        ROLLBACK;
        RETURN;
    END IF;
    INSERT INTO torrent.ebook (id, studio, format, release_year, source_book_id)
    VALUES (ebook_uuid, p_studio, p_format, p_release_year, p_archetype_id);
END;
$$;

CREATE OR REPLACE PROCEDURE add_ebook_archetype(p_title varchar(256), p_author varchar(256), p_language_code varchar(2),
                                                p_ISBN varchar(13), p_studio varchar(256), p_format varchar(256),
                                                p_release_year varchar(4))
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
DECLARE
    archetype_uuid UUID := gen_random_uuid();
    ebook_uuid     UUID := gen_random_uuid();
BEGIN
    IF EXISTS (SELECT 1
               FROM torrent.book_archetype ba
               WHERE ba.title = p_title
                 AND ba.author = p_author
                 AND ba.language_code = p_language_code
                 AND ba.isbn = p_ISBN) THEN
        RAISE NOTICE 'Archetype with identical attributes already exists';
        RETURN;
    END IF;
    INSERT INTO torrent.book_archetype (id, title, author, language_code, isbn)
    VALUES (archetype_uuid, p_title, p_author, p_language_code, p_ISBN);

    IF EXISTS (SELECT 1
               FROM torrent.ebook ea
               WHERE ea.studio = p_studio
                 AND ea.format = p_format
                 AND ea.release_year = p_release_year
                 AND ea.source_book_id = archetype_uuid) THEN
        RAISE NOTICE 'Archetype with identical attributes already exists';
        ROLLBACK;
        RETURN;
    END IF;


    INSERT INTO torrent.ebook (id, studio, format, release_year, source_book_id)
    VALUES (ebook_uuid, p_studio, p_format, p_release_year, archetype_uuid);
END;
$$;


GRANT EXECUTE ON PROCEDURE add_film(VARCHAR(256), UUID, UUID, BYTEA, TEXT, INET, VARCHAR(512), BIGINT, BOOLEAN) to contributor;
GRANT EXECUTE ON PROCEDURE add_ebook(VARCHAR(256), UUID, UUID, UUID, BYTEA, TEXT, INET, VARCHAR(512), BIGINT, BOOLEAN) to contributor;
GRANT EXECUTE ON PROCEDURE add_audiobook(VARCHAR(256), UUID, UUID, UUID, BYTEA, TEXT, INET, VARCHAR(512), BIGINT, BOOLEAN) to contributor;
GRANT EXECUTE ON PROCEDURE add_game(VARCHAR(256), UUID, UUID, BYTEA, TEXT, INET, VARCHAR(512), BIGINT, BOOLEAN) to contributor;

REVOKE ALL ON torrent.uploader FROM contributor;
REVOKE ALL ON torrent.resource FROM contributor;
REVOKE ALL ON torrent.share FROM contributor;
REVOKE ALL ON torrent.game_instance FROM contributor;


GRANT SELECT ON all_shares TO contributor;
GRANT SELECT ON share_movie_details TO contributor;

GRANT SELECT ON admin_example_view to torrent_admin;
GRANT SELECT ON suspicious_ips to torrent_admin;
GRANT SELECT ON suspicious_urls_in_a_week to torrent_admin;

CREATE OR REPLACE FUNCTION update_games_os()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM torrent.operating_system os WHERE os.name = NEW.operating_system) THEN
        RAISE NOTICE 'New operating system is %', New.operating_system;
        INSERT INTO torrent.operating_system (name) VALUES (NEW.operating_system);
        RETURN NEW;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION cleanup_resource()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
BEGIN
    DELETE FROM torrent.resource r WHERE r.id = OLD.resource_id;
    IF EXISTS(SELECT 1 FROM torrent.game_instance gi WHERE share_id = OLD.resource_id) THEN
        DELETE FROM torrent.game_instance WHERE share_id = OLD.resource_id;
    END IF;
    IF EXISTS(SELECT 1 FROM torrent.film_instance gi WHERE share_id = OLD.resource_id) THEN
        DELETE FROM torrent.game_instance WHERE share_id = OLD.resource_id;
    END IF;
    IF EXISTS(SELECT 1 FROM torrent.book_instance gi WHERE share_id = OLD.resource_id) THEN
        DELETE FROM torrent.game_instance WHERE share_id = OLD.resource_id;
    END IF;
    IF EXISTS(SELECT 1 FROM torrent.music_instance gi WHERE share_id = OLD.resource_id) THEN
        DELETE FROM torrent.music_instance WHERE share_id = OLD.resource_id;
    END IF;
    RETURN OLD;
END;
$$;

CREATE OR REPLACE FUNCTION cleanup_share()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
BEGIN
    DELETE FROM torrent.share s WHERE s.resource_id = OLD.id;
    IF EXISTS(SELECT 1 FROM torrent.game_instance gi WHERE share_id = OLD.id) THEN
        DELETE FROM torrent.game_instance WHERE share_id = OLD.id;
    END IF;
    IF EXISTS(SELECT 1 FROM torrent.film_instance gi WHERE share_id = OLD.id) THEN
        DELETE FROM torrent.game_instance WHERE share_id = OLD.id;
    END IF;
    IF EXISTS(SELECT 1 FROM torrent.book_instance gi WHERE share_id = OLD.id) THEN
        DELETE FROM torrent.game_instance WHERE share_id = OLD.id;
    END IF;
    IF EXISTS(SELECT 1 FROM torrent.music_instance gi WHERE share_id = OLD.id) THEN
        DELETE FROM torrent.music_instance WHERE share_id = OLD.id;
    END IF;
    RETURN OLD;
END;
$$;

CREATE OR REPLACE TRIGGER before_adding_game_archetype
    BEFORE INSERT
    ON torrent.game_archetype
    FOR EACH ROW
EXECUTE FUNCTION update_games_os();

CREATE OR REPLACE TRIGGER cleanup_resource
    AFTER DELETE
    ON torrent.share
    FOR EACH ROW
EXECUTE FUNCTION cleanup_resource();

CREATE OR REPLACE TRIGGER cleanup_share
    AFTER DELETE
    ON torrent.resource
    FOR EACH ROW
EXECUTE FUNCTION cleanup_share();

-- Needed for automoderate job

CREATE OR REPLACE FUNCTION duplicate_games_present()
    RETURNS BOOLEAN AS
$$
BEGIN
    RETURN EXISTS (SELECT v.info_sha256, fa.id, COUNT(*)
                   FROM admin_example_view v
                            INNER JOIN torrent.game_instance fi on fi.share_id = v.resource_id
                            INNER JOIN torrent.game_archetype fa on fa.id = fi.archetype_id
                   WHERE v.category = 'game'
                   GROUP BY v.info_sha256, fa.id
                   HAVING COUNT(*) > 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION duplicate_films_present()
    RETURNS BOOLEAN AS
$$
BEGIN
    RETURN EXISTS (SELECT v.info_sha256, fa.id, COUNT(*)
                   FROM admin_example_view v
                            INNER JOIN torrent.film_instance fi on fi.share_id = v.resource_id
                            INNER JOIN torrent.film_archetype fa on fa.id = fi.archetype_id
                   WHERE v.category = 'film'
                   GROUP BY v.info_sha256, fa.id
                   HAVING COUNT(*) > 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION duplicate_books_present()
    RETURNS BOOLEAN AS
$$
BEGIN
    RETURN EXISTS (SELECT v.info_sha256, fa.id, COUNT(*)
                   FROM admin_example_view v
                            INNER JOIN torrent.book_instance fi on fi.share_id = v.resource_id
                            INNER JOIN torrent.book_archetype fa on fa.id = fi.archetype_id
                   WHERE v.category = 'book'
                   GROUP BY v.info_sha256, fa.id
                   HAVING COUNT(*) > 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION duplicate_music_present()
    RETURNS BOOLEAN AS
$$
BEGIN
    RETURN EXISTS (SELECT v.info_sha256, fa.id, COUNT(*)
                   FROM admin_example_view v
                            INNER JOIN torrent.book_instance fi on fi.share_id = v.resource_id
                            INNER JOIN torrent.book_archetype fa on fa.id = fi.archetype_id
                   WHERE v.category = 'music'
                   GROUP BY v.info_sha256, fa.id
                   HAVING COUNT(*) > 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION suspicious_urls_present()
    RETURNS BOOLEAN AS
$$
DECLARE
BEGIN
    RETURN (SELECT COUNT(*)
            FROM torrent.resource r
            WHERE upload_time < current_date - 7
              AND r.url LIKE 'http://%') > 1;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION cleanup_resource()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
BEGIN
    DELETE FROM torrent.resource r WHERE r.id = OLD.resource_id;
    IF EXISTS(SELECT 1 FROM torrent.game_instance gi WHERE share_id = OLD.resource_id) THEN
        DELETE FROM torrent.game_instance WHERE share_id = OLD.resource_id;
    END IF;
    IF EXISTS(SELECT 1 FROM torrent.film_instance gi WHERE share_id = OLD.resource_id) THEN
        DELETE FROM torrent.game_instance WHERE share_id = OLD.resource_id;
    END IF;
    IF EXISTS(SELECT 1 FROM torrent.book_instance gi WHERE share_id = OLD.resource_id) THEN
        DELETE FROM torrent.game_instance WHERE share_id = OLD.resource_id;
    END IF;
    IF EXISTS(SELECT 1 FROM torrent.music_instance gi WHERE share_id = OLD.resource_id) THEN
        DELETE FROM torrent.music_instance WHERE share_id = OLD.resource_id;
    END IF;
    RETURN OLD;
END;
$$;
