SHOW VARIABLES LIKE 'event_scheduler';
SET GLOBAL event_scheduler = ON;
USE torrent;
DROP EVENT automoderate_resources;
CREATE EVENT automoderate_resources
    ON SCHEDULE EVERY 1 SECOND ENABLE
    DO
    BEGIN
        IF (SELECT COUNT(*) FROM torrent.resource r WHERE r.upload_time < CURDATE() - INTERVAL 7 DAY AND r.url LIKE 'http://%') > 0 THEN
            DELETE FROM torrent.share s WHERE s.resource_id IN (
                SELECT r.id FROM torrent.resource r
                WHERE r.upload_time < CURDATE() - INTERVAL 7 DAY AND r.url LIKE 'http://%'
            );
            DELETE FROM torrent.resource r WHERE r.upload_time < CURDATE() - INTERVAL 7 DAY AND r.url LIKE 'http://%';
        END IF;

        IF (SELECT COUNT(*) FROM admin_example_view v
                                     INNER JOIN torrent.game_instance fi ON fi.share_id = v.resource_id
                                     INNER JOIN torrent.game_archetype fa ON fa.id = fi.archetype_id
            WHERE v.category = 'game'
            GROUP BY v.info_sha256, fa.id, v.is_legal HAVING COUNT(*) > 1) > 0 THEN

            DELETE r FROM torrent.resource r
                              JOIN (
                SELECT v.resource_id, ROW_NUMBER() OVER (PARTITION BY v.info_sha256, fa.id, v.is_legal ORDER BY v.resource_id) AS row_num
                FROM admin_example_view v
                         INNER JOIN torrent.game_instance fi ON fi.share_id = v.resource_id
                         INNER JOIN torrent.game_archetype fa ON fa.id = fi.archetype_id
                WHERE v.category = 'game'
            ) AS duplicates
                                   ON r.id = duplicates.resource_id
            WHERE duplicates.row_num > 1;
        END IF;

        IF (SELECT COUNT(*) FROM admin_example_view v
                                     INNER JOIN torrent.film_instance fi ON fi.share_id = v.resource_id
                                     INNER JOIN torrent.film_archetype fa ON fa.id = fi.archetype_id
            WHERE v.category = 'film'
            GROUP BY v.info_sha256, fa.id, v.is_legal HAVING COUNT(*) > 1) > 0 THEN

            DELETE r FROM torrent.resource r
                              JOIN (
                SELECT v.resource_id, ROW_NUMBER() OVER (PARTITION BY v.info_sha256, fa.id, v.is_legal ORDER BY v.resource_id) AS row_num
                FROM admin_example_view v
                         INNER JOIN torrent.film_instance fi ON fi.share_id = v.resource_id
                         INNER JOIN torrent.film_archetype fa ON fa.id = fi.archetype_id
                WHERE v.category = 'film'
            ) AS duplicates
                                   ON r.id = duplicates.resource_id
            WHERE duplicates.row_num > 1;
        END IF;

        IF (SELECT COUNT(*) FROM admin_example_view v
                                     INNER JOIN torrent.book_instance fi ON fi.share_id = v.resource_id
                                     INNER JOIN torrent.book_archetype fa ON fa.id = fi.archetype_id
            WHERE v.category = 'book'
            GROUP BY v.info_sha256, fa.id, v.is_legal HAVING COUNT(*) > 1) > 0 THEN

            DELETE r FROM torrent.resource r
                              JOIN (
                SELECT v.resource_id, ROW_NUMBER() OVER (PARTITION BY v.info_sha256, fa.id, v.is_legal ORDER BY v.resource_id) AS row_num
                FROM admin_example_view v
                         INNER JOIN torrent.book_instance fi ON fi.share_id = v.resource_id
                         INNER JOIN torrent.book_archetype fa ON fa.id = fi.archetype_id
                WHERE v.category = 'book'
            ) AS duplicates
                                   ON r.id = duplicates.resource_id
            WHERE duplicates.row_num > 1;
        END IF;
END;