CREATE OR REPLACE PROCEDURE autosynchronize_torrent(dblink_name VARCHAR(256), db_user VARCHAR(256),
                                                    db_password VARCHAR(256), db_name VARCHAR(256),
                                                    host VARCHAR(256))
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
DECLARE
    connected         BOOLEAN;
    connection_string TEXT;
BEGIN
    ASSERT dblink_name IS NOT NULL, 'All arguments must be provided';
    ASSERT db_user IS NOT NULL, 'All arguments must be provided';
    ASSERT db_password IS NOT NULL, 'All arguments must be provided';
    ASSERT db_name IS NOT NULL, 'All arguments must be provided';
    ASSERT host IS NOT NULL, 'All arguments must be provided';


    CREATE extension IF NOT EXISTS dblink;

    connection_string := FORMAT('host=%I user=%I password=%L dbname=%I', host, db_user, db_password, db_name);


    PERFORM dblink_connect(dblink_name, connection_string);
    connected := TRUE;

    INSERT INTO torrent.uploader (id, name, recently_active, first_logged_in, recently_used_ip, first_used_ip)
    SELECT id, name, recently_active, first_logged_in, recently_used_ip, first_used_ip
    FROM dblink(
                 'replica',
                 'SELECT id, name, recently_active, first_logged_in, recently_used_ip, first_used_ip FROM torrent.uploader'
         ) AS result(id UUID, name VARCHAR(50), recently_active TIMESTAMP, first_logged_in timestamp,
                     recently_used_ip inet,
                     first_used_ip inet)
    ON CONFLICT DO NOTHING;

    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    SELECT id,
           upload_time,
           leeches,
           seeders,
           info_sha256,
           url,
           is_legal,
           size_in_bytes
    FROM dblink(
                 'replica',
                 'SELECT id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes FROM torrent.resource'
         ) AS result(id UUID, upload_time TIMESTAMP, leeches SMALLINT, seeders SMALLINT, info_sha256 BYTEA, url TEXT,
                     is_legal BOOLEAN, size_in_bytes BIGINT)
    ON CONFLICT DO NOTHING;


    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    SELECT resource_id,
           title,
           description,
           uploader_id,
           category
    FROM dblink(
                 'replica',
                 'SELECT resource_id, title, description, uploader_id, category FROM torrent.share'
         ) AS result(resource_id UUID, title VARCHAR(256), description VARCHAR(512), uploader_id UUID,
                     category VARCHAR(10))
    ON CONFLICT DO NOTHING;


    INSERT INTO torrent.film_archetype (id, title, format, language_code, resolution, release_year, length_in_minutes)
    SELECT id, title, format, language_code, resolution, release_year, length_in_minutes
    FROM dblink(
                 'replica',
                 'SELECT id, title, format, language_code, resolution, release_year, length_in_minutes FROM torrent.film_archetype'
         ) AS result(id UUID, title VARCHAR(256), format VARCHAR(256), language_code VARCHAR(2), resolution VARCHAR(9),
                     release_year VARCHAR(4), length_in_minutes SMALLINT)
    ON CONFLICT DO NOTHING;


    INSERT INTO torrent.music_archetype (id, length_epoch, format, album_name, release_year)
    SELECT id, length_epoch, format, album_name, release_year
    FROM dblink(
                 'replica',
                 'SELECT id, length_epoch, format, album_name, release_year FROM torrent.music_archetype'
         ) AS result(id UUID, length_epoch SMALLINT, format VARCHAR(6), album_name VARCHAR(256),
                     release_year VARCHAR(4))
    ON CONFLICT DO NOTHING;


    INSERT INTO torrent.game_archetype (id, title, studio, language_code, release_year, operating_system)
    SELECT id, title, studio, language_code, release_year, operating_system
    FROM dblink(
                 'replica',
                 'SELECT id, title, studio, language_code, release_year, operating_system FROM torrent.game_archetype'
         ) AS result(id UUID, title VARCHAR(256), studio VARCHAR(256), language_code VARCHAR(2),
                     release_year VARCHAR(4),
                     operating_system VARCHAR(10))
    ON CONFLICT DO NOTHING;


    INSERT INTO torrent.book_archetype (id, title, author, language_code, isbn)
    SELECT id, title, author, language_code, isbn
    FROM dblink(
                 'replica',
                 'SELECT id, title, author, language_code, isbn FROM torrent.book_archetype'
         ) AS result(id UUID, title VARCHAR(256), author VARCHAR(256), language_code VARCHAR(2), isbn VARCHAR(13))
    ON CONFLICT DO NOTHING;


    INSERT INTO torrent.audio_book (id, studio, read_by, language_code, length_epoch, format, release_year,
                                    source_book_id)
    SELECT id,
           studio,
           read_by,
           language_code,
           length_epoch,
           format,
           release_year,
           source_book_id
    FROM dblink(
                 'replica',
                 'SELECT id, studio, read_by, language_code, length_epoch, format, release_year, source_book_id FROM torrent.audio_book'
         ) AS result(id UUID, studio VARCHAR(256), read_by VARCHAR(256), language_code VARCHAR(2),
                     length_epoch SMALLINT,
                     format VARCHAR(6), release_year VARCHAR(4), source_book_id UUID)
    ON CONFLICT DO NOTHING;


    INSERT INTO torrent.ebook (id, studio, format, release_year, source_book_id)
    SELECT id, studio, format, release_year, source_book_id
    FROM dblink(
                 'replica',
                 'SELECT id, studio, format, release_year, source_book_id FROM torrent.ebook'
         ) AS result(id UUID, studio VARCHAR(256), format VARCHAR(6), release_year VARCHAR(4), source_book_id UUID)
    ON CONFLICT DO NOTHING;


    INSERT INTO torrent.film_instance (share_id, archetype_id)
    SELECT share_id,
           archetype_id
    FROM dblink(
                 'replica',
                 'SELECT share_id, archetype_id FROM torrent.film_instance'
         ) AS result(share_id UUID, archetype_id UUID)
    ON CONFLICT DO NOTHING;


    INSERT INTO torrent.game_instance (share_id, archetype_id)
    SELECT share_id,
           archetype_id
    FROM dblink(
                 'replica',
                 'SELECT share_id, archetype_id FROM torrent.game_instance'
         ) AS result(share_id UUID, archetype_id UUID)
    ON CONFLICT DO NOTHING;


    INSERT INTO torrent.book_instance (share_id, archetype_id)
    SELECT share_id,
           archetype_id
    FROM dblink(
                 'replica',
                 'SELECT share_id, archetype_id FROM torrent.book_instance'
         ) AS result(share_id UUID, archetype_id UUID)
    ON CONFLICT DO NOTHING;


    INSERT INTO torrent.music_instance (share_id, archetype_id)
    SELECT share_id,
           archetype_id
    FROM dblink(
                 'replica',
                 'SELECT share_id, archetype_id FROM torrent.music_instance'
         ) AS result(share_id UUID, archetype_id UUID)
    ON CONFLICT DO NOTHING;

    PERFORM dblink_disconnect('replica');
    connected := FALSE;

EXCEPTION
    WHEN OTHERS THEN
        -- Rollback the transaction if any exception occurs
        IF connected THEN
            PERFORM dblink_disconnect('replica');
        END IF;
        RAISE EXCEPTION 'Error during autosynchronize_torrent: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE autosynchronize_torrent_on_gresik()
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
BEGIN
    CALL autosynchronize_torrent('replica', 'postgres', 'mysecretpassword', 'postgres', 'gresik');
END;
$$;

-- Setup cron

SELECT cron.schedule('autosync_every_minute', '* * * * *', $$CALL autosynchronize_torrent_on_gresik()$$);


SELECT jobid,
       schedule,
       command
FROM cron.job;

CREATE OR REPLACE PROCEDURE check_record_counts(dblink_name VARCHAR(256), db_user VARCHAR(256),
                                                db_password VARCHAR(256), db_name VARCHAR(256),
                                                host VARCHAR(256))
    LANGUAGE plpgsql
AS $$
DECLARE
    connection_string TEXT;
    local_count INT;
    remote_count INT;
    table_name TEXT;
    mismatch TEXT := '';

BEGIN
    ASSERT dblink_name IS NOT NULL, 'All arguments must be provided';
    ASSERT db_user IS NOT NULL, 'All arguments must be provided';
    ASSERT db_password IS NOT NULL, 'All arguments must be provided';
    ASSERT db_name IS NOT NULL, 'All arguments must be provided';
    ASSERT host IS NOT NULL, 'All arguments must be provided';

    connection_string := FORMAT('host=%I user=%I password=%L dbname=%I', host, db_user, db_password, db_name);

    PERFORM dblink_connect(dblink_name, connection_string);

    FOR table_name IN
        SELECT unnest(ARRAY[
            'uploader', 'resource', 'share', 'film_archetype', 'music_archetype',
            'game_archetype', 'book_archetype', 'audio_book', 'ebook',
            'film_instance', 'game_instance', 'book_instance', 'music_instance'
            ])
        LOOP
            EXECUTE format('SELECT COUNT(*) FROM torrent.%I', table_name) INTO local_count;

            EXECUTE format(
                    'SELECT COUNT(*) FROM dblink(''%s'', ''SELECT COUNT(*) FROM torrent.%I'') AS result(count INT)',
                    dblink_name, table_name
                    ) INTO remote_count;

            IF local_count != remote_count THEN
                mismatch := mismatch || format('%s: Local count = %s, Remote count = %s; ', table_name, local_count, remote_count);
            END IF;
        END LOOP;

    IF mismatch != '' THEN
        RAISE EXCEPTION 'Record count mismatch detected: %', mismatch;
    ELSE
        RAISE NOTICE 'All record counts match between local and remote tables.';
    END IF;

    PERFORM dblink_disconnect(dblink_name);

EXCEPTION
    WHEN OTHERS THEN
        PERFORM dblink_disconnect(dblink_name);
        RAISE EXCEPTION 'Error during record count check: %', SQLERRM;
END;
$$;

CALL check_record_counts('replica', 'postgres', 'mysecretpassword', 'postgres', 'gresik');