CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE OR REPLACE PROCEDURE automoderate_resources()
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
BEGIN
    IF suspicious_urls_present() THEN
        -- delete share and resource and instance
        DELETE
        FROM resource r
        WHERE r.id IN (SELECT *
                       FROM torrent.resource r
                       WHERE upload_time < current_date - 7
                         AND r.url LIKE 'http://%');
        IF suspicious_urls_present() THEN
            RAISE NOTICE 'Some suspicious IPs were not deleted fo unknown reason.';
        END IF;
        -- delete duplicates if the same category and pointing to the same archetype with the same legality status
        -- if not the same category or archetype, raise notice for admin investigation
        IF duplicate_games_present() THEN
            WITH hard_duplicated_entries AS (SELECT v.resource_id,
                                                    v.info_sha256,
                                                    fa.id,
                                                    v.is_legal,
                                                    ROW_NUMBER() over (PARTITION BY info_sha256, id, is_legal) AS row_num
                                             FROM admin_example_view v
                                                      INNER JOIN torrent.game_instance fi on fi.share_id = v.resource_id
                                                      INNER JOIN torrent.game_archetype fa on fa.id = fi.archetype_id
                                             WHERE v.category = 'game')
            DELETE
            FROM torrent.resource r
            WHERE r.id IN (SELECT hard_duplicated_entries.resource_id FROM hard_duplicated_entries WHERE row_num > 1);
            IF duplicate_games_present() THEN
                RAISE NOTICE 'Some games duplicates were not deleted fo unknown reason.';
            END IF;

        END IF;
        IF duplicate_films_present() THEN
            WITH hard_duplicated_entries AS (SELECT v.resource_id,
                                                    v.info_sha256,
                                                    fa.id,
                                                    v.is_legal,
                                                    ROW_NUMBER() over (PARTITION BY info_sha256, id, is_legal) AS row_num
                                             FROM admin_example_view v
                                                      INNER JOIN torrent.film_instance fi on fi.share_id = v.resource_id
                                                      INNER JOIN torrent.film_archetype fa on fa.id = fi.archetype_id
                                             WHERE v.category = 'game')
            DELETE
            FROM torrent.resource r
            WHERE r.id IN (SELECT hard_duplicated_entries.resource_id FROM hard_duplicated_entries WHERE row_num > 1);
            IF duplicate_films_present() THEN
                RAISE NOTICE 'Some films duplicates were not deleted fo unknown reason.';
            END IF;
        END IF;
        IF duplicate_books_present() THEN
            WITH hard_duplicated_entries AS (SELECT v.resource_id,
                                                    v.info_sha256,
                                                    fa.id,
                                                    v.is_legal,
                                                    ROW_NUMBER() over (PARTITION BY info_sha256, id, is_legal) AS row_num
                                             FROM admin_example_view v
                                                      INNER JOIN torrent.book_instance fi on fi.share_id = v.resource_id
                                                      INNER JOIN torrent.book_archetype fa on fa.id = fi.archetype_id
                                             WHERE v.category = 'game')
            DELETE
            FROM torrent.resource r
            WHERE r.id IN (SELECT hard_duplicated_entries.resource_id FROM hard_duplicated_entries WHERE row_num > 1);
            IF duplicate_books_present() THEN
                RAISE NOTICE 'Some books duplicates were not deleted fo unknown reason.';
            END IF;
        END IF;
        IF duplicate_music_present() THEN
            WITH hard_duplicated_entries AS (SELECT v.resource_id,
                                                    v.info_sha256,
                                                    fa.id,
                                                    v.is_legal,
                                                    ROW_NUMBER() over (PARTITION BY info_sha256, id, is_legal) AS row_num
                                             FROM admin_example_view v
                                                      INNER JOIN torrent.music_instance fi on fi.share_id = v.resource_id
                                                      INNER JOIN torrent.music_archetype fa on fa.id = fi.archetype_id
                                             WHERE v.category = 'game')
            DELETE
            FROM torrent.resource r
            WHERE r.id IN (SELECT hard_duplicated_entries.resource_id FROM hard_duplicated_entries WHERE row_num > 1);
            IF duplicate_music_present() THEN
                RAISE NOTICE 'Some books duplicates were not deleted fo unknown reason.';
            END IF;
        END IF;
    END IF;
END;
$$;

SELECT cron.schedule('automodaret_every_minute', '* * * * *', $$CALL automoderate_resources()$$);
SELECT cron.schedule('autosync_every_minute', '* * * * *', $$CALL autosynchronize_torrent_on_gresik()$$);


SELECT jobid,
       schedule,
       command
FROM cron.job;