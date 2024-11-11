--
-- PostgreSQL database cluster dump
--

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Roles
--

CREATE ROLE contributor;
ALTER ROLE contributor WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS;
CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS PASSWORD 'SCRAM-SHA-256$4096:J1auSbS7eWptGmxHXDBW5Q==$oidU95oiflfTlZlYQVBgd8X0QWfDuRmPqJm0mrPO8KM=:C3EeUtclWEtvkYWM664NKlmsLRBlS2Sk6Qd+5lJuSpg=';
CREATE ROLE torrent_admin;
ALTER ROLE torrent_admin WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'SCRAM-SHA-256$4096:bMtpbyEDkBXoiMNZItS3KQ==$52ynK8sFERMxh+dT0T97eWifek7bl8vUHwKUJqwQhd4=:I7TJXTPNy9XY4T3hRa3qQECL0dEmAyBkbKbLpjHvTc0=';

--
-- User Configurations
--








--
-- Databases
--

--
-- Database "template1" dump
--

\connect template1

--
-- PostgreSQL database dump
--

-- Dumped from database version 17.0 (Debian 17.0-1.pgdg120+1)
-- Dumped by pg_dump version 17.0 (Debian 17.0-1.pgdg120+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- PostgreSQL database dump complete
--

--
-- Database "postgres" dump
--

\connect postgres

--
-- PostgreSQL database dump
--

-- Dumped from database version 17.0 (Debian 17.0-1.pgdg120+1)
-- Dumped by pg_dump version 17.0 (Debian 17.0-1.pgdg120+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: torrent; Type: SCHEMA; Schema: -; Owner: torrent_admin
--

CREATE SCHEMA torrent;


ALTER SCHEMA torrent OWNER TO torrent_admin;

--
-- Name: btree_gin; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA public;


--
-- Name: EXTENSION btree_gin; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION btree_gin IS 'support for indexing common datatypes in GIN';


--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: add(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add(integer, integer) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$select $1 + $2;$_$;


ALTER FUNCTION public.add(integer, integer) OWNER TO postgres;

--
-- Name: add_audiobook(character varying, uuid, uuid, uuid, bytea, text, inet, character varying, bigint, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_audiobook(IN p_title character varying, IN p_book_archetype uuid, IN p_audio_book uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying DEFAULT NULL::character varying, IN p_size_in_bytes bigint DEFAULT 0, IN p_is_legal boolean DEFAULT false)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
    INSERT INTO torrent.book_instance (share_id, archetype_id) VALUES (resource_uuid, p_game_archetype_id);
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
$$;


ALTER PROCEDURE public.add_audiobook(IN p_title character varying, IN p_book_archetype uuid, IN p_audio_book uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean) OWNER TO postgres;

--
-- Name: add_book_archetype(character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_book_archetype(IN p_title character varying, IN p_author character varying, IN p_language_code character varying, IN p_isbn character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER PROCEDURE public.add_book_archetype(IN p_title character varying, IN p_author character varying, IN p_language_code character varying, IN p_isbn character varying) OWNER TO postgres;

--
-- Name: add_ebook(character varying, uuid, uuid, uuid, bytea, text, inet, character varying, bigint, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_ebook(IN p_title character varying, IN p_book_archetype uuid, IN p_ebook uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying DEFAULT NULL::character varying, IN p_size_in_bytes bigint DEFAULT 0, IN p_is_legal boolean DEFAULT false)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
    INSERT INTO torrent.book_instance (share_id, archetype_id) VALUES (resource_uuid, p_game_archetype_id);
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
$$;


ALTER PROCEDURE public.add_ebook(IN p_title character varying, IN p_book_archetype uuid, IN p_ebook uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean) OWNER TO postgres;

--
-- Name: add_ebook_archetype(character varying, character varying, character varying, uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_ebook_archetype(IN p_studio character varying, IN p_format character varying, IN p_release_year character varying, IN p_archetype_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER PROCEDURE public.add_ebook_archetype(IN p_studio character varying, IN p_format character varying, IN p_release_year character varying, IN p_archetype_id uuid) OWNER TO postgres;

--
-- Name: add_ebook_archetype(character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_ebook_archetype(IN p_title character varying, IN p_author character varying, IN p_language_code character varying, IN p_isbn character varying, IN p_studio character varying, IN p_format character varying, IN p_release_year character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER PROCEDURE public.add_ebook_archetype(IN p_title character varying, IN p_author character varying, IN p_language_code character varying, IN p_isbn character varying, IN p_studio character varying, IN p_format character varying, IN p_release_year character varying) OWNER TO postgres;

--
-- Name: add_film(character varying, uuid, uuid, bytea, text, inet, character varying, bigint, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_film(IN p_title character varying, IN p_film_archetype uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying DEFAULT NULL::character varying, IN p_size_in_bytes bigint DEFAULT 0, IN p_is_legal boolean DEFAULT false)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
        RAISE NOTICE 'Either one of foreign keys does not exist and no previous errors were raised: game_archetype(%), uploader_id(%)', p_game_archetype_id, p_uploader_id;
        ROLLBACK;
    WHEN OTHERS THEN
        RAISE NOTICE 'An unexpected error occurred: %', SQLERRM;
        ROLLBACK;
END;
$$;


ALTER PROCEDURE public.add_film(IN p_title character varying, IN p_film_archetype uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean) OWNER TO postgres;

--
-- Name: add_game(uuid, text, bigint, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_game(IN uploader_id uuid, IN url text, IN size_in_bytes bigint DEFAULT 0, IN is_legal boolean DEFAULT false)
    LANGUAGE plpgsql
    AS $$
    DECLARE
        resource_uuid UUID := gen_random_uuid();
BEGIN
    ROLLBACK;
    INSERT INTO resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    values (resource_uuid, now(), 0, 0, digest(gen_random_uuid()::text, 'sha256'), url, is_legal, size_in_bytes);
END;
$$;


ALTER PROCEDURE public.add_game(IN uploader_id uuid, IN url text, IN size_in_bytes bigint, IN is_legal boolean) OWNER TO postgres;

--
-- Name: add_game(character varying, uuid, uuid, text, character varying, bigint, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_game(IN p_title character varying, IN p_game_archetype_id uuid, IN p_uploader_id uuid, IN p_url text, IN p_description character varying DEFAULT NULL::character varying, IN p_size_in_bytes bigint DEFAULT 0, IN p_is_legal boolean DEFAULT false)
    LANGUAGE plpgsql
    AS $$
DECLARE
    resource_uuid          UUID      := gen_random_uuid();
    inserted_into_category VARCHAR   := 'game';
    random_sha256          BYTEA     := digest(gen_random_uuid()::text, 'sha256');
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
    -- Resource
    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    values (resource_uuid, now_ts, 0, 0, random_sha256, p_url, p_is_legal, p_size_in_bytes);
    -- Share
    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    values (resource_uuid, p_title, p_description, p_uploader_id, inserted_into_category);
    -- Connect them and the archetype through an instance
    INSERT INTO torrent.game_instance (share_id, archetype_id) VALUES (resource_uuid, p_game_archetype_id);

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
$$;


ALTER PROCEDURE public.add_game(IN p_title character varying, IN p_game_archetype_id uuid, IN p_uploader_id uuid, IN p_url text, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean) OWNER TO postgres;

--
-- Name: add_game(character varying, uuid, uuid, bytea, text, character varying, bigint, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_game(IN p_title character varying, IN p_game_archetype_id uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_description character varying DEFAULT NULL::character varying, IN p_size_in_bytes bigint DEFAULT 0, IN p_is_legal boolean DEFAULT false)
    LANGUAGE plpgsql
    AS $$
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
    -- Resource
    INSERT INTO torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes)
    values (resource_uuid, now_ts, 0, 0, file_sha, p_url, p_is_legal, p_size_in_bytes);
    -- Share
    INSERT INTO torrent.share (resource_id, title, description, uploader_id, category)
    values (resource_uuid, p_title, p_description, p_uploader_id, inserted_into_category);
    -- Connect them and the archetype through an instance
    INSERT INTO torrent.game_instance (share_id, archetype_id) VALUES (resource_uuid, p_game_archetype_id);

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
$$;


ALTER PROCEDURE public.add_game(IN p_title character varying, IN p_game_archetype_id uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean) OWNER TO postgres;

--
-- Name: add_game(character varying, uuid, uuid, bytea, text, inet, character varying, bigint, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_game(IN p_title character varying, IN p_game_archetype_id uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying DEFAULT NULL::character varying, IN p_size_in_bytes bigint DEFAULT 0, IN p_is_legal boolean DEFAULT false)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER PROCEDURE public.add_game(IN p_title character varying, IN p_game_archetype_id uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean) OWNER TO postgres;

--
-- Name: add_game_archetype(character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_game_archetype(IN p_title character varying, IN p_studio character varying, IN p_language_code character varying, IN p_release_year character varying, IN p_os character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER PROCEDURE public.add_game_archetype(IN p_title character varying, IN p_studio character varying, IN p_language_code character varying, IN p_release_year character varying, IN p_os character varying) OWNER TO postgres;

--
-- Name: add_music(character varying, uuid, uuid, bytea, text, inet, character varying, bigint, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_music(IN p_title character varying, IN p_music_archetype uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying DEFAULT NULL::character varying, IN p_size_in_bytes bigint DEFAULT 0, IN p_is_legal boolean DEFAULT false)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
    INSERT INTO torrent.music_instance (share_id, archetype_id) VALUES (resource_uuid, p_game_archetype_id);
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
$$;


ALTER PROCEDURE public.add_music(IN p_title character varying, IN p_music_archetype uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean) OWNER TO postgres;

--
-- Name: cleanup_resource(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cleanup_resource() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    DELETE FROM torrent.resource r WHERE r.id = OLD.resource_id ;
    DELETE FROM torrent.game_instance WHERE share_id = OLD.resource_id;
    RETURN OLD;
END;
$$;


ALTER FUNCTION public.cleanup_resource() OWNER TO postgres;

--
-- Name: is_ip_in_ranges(inet, inet[], inet[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_ip_in_ranges(ip_address inet, range_starts inet[], range_ends inet[]) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.is_ip_in_ranges(ip_address inet, range_starts inet[], range_ends inet[]) OWNER TO postgres;

--
-- Name: is_ip_in_ranges_puresql(inet, inet[], inet[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_ip_in_ranges_puresql(ip_address inet, range_starts inet[], range_ends inet[]) RETURNS boolean
    LANGUAGE sql
    AS $$
SELECT EXISTS (
    SELECT 1
    FROM UNNEST(range_starts, range_ends) AS ranges(start_ip, end_ip)
    WHERE ip_address BETWEEN start_ip AND end_ip
);
$$;


ALTER FUNCTION public.is_ip_in_ranges_puresql(ip_address inet, range_starts inet[], range_ends inet[]) OWNER TO postgres;

--
-- Name: is_within_range(inet, inet, inet); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_within_range(ip_address inet, range_start inet, range_end inet) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
    BEGIN
        RETURN ip_address >= range_start AND ip_address <= range_end;
    END;
$$;


ALTER FUNCTION public.is_within_range(ip_address inet, range_start inet, range_end inet) OWNER TO postgres;

--
-- Name: music(character varying, uuid, uuid, bytea, text, inet, character varying, bigint, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.music(IN p_title character varying, IN p_music_archetype uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying DEFAULT NULL::character varying, IN p_size_in_bytes bigint DEFAULT 0, IN p_is_legal boolean DEFAULT false)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
    INSERT INTO torrent.music_instance (share_id, archetype_id) VALUES (resource_uuid, p_game_archetype_id);
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
$$;


ALTER PROCEDURE public.music(IN p_title character varying, IN p_music_archetype uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean) OWNER TO postgres;

--
-- Name: update_games_os(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_games_os() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM torrent.operating_system os WHERE os.name = NEW.operating_system) THEN
        RAISE NOTICE 'New operating system is %', New.operating_system;
        INSERT INTO torrent.operating_system (name) VALUES (NEW.operating_system);
        RETURN NEW;
    END IF;
END;
$$;


ALTER FUNCTION public.update_games_os() OWNER TO postgres;

--
-- Name: update_games_os(character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.update_games_os(IN p_os character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM torrent.operating_system os WHERE os.name = p_os) THEN
        INSERT INTO torrent.operating_system (name) VALUES (p_os);
    END IF;
END;
$$;


ALTER PROCEDURE public.update_games_os(IN p_os character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: resource; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.resource (
    id uuid NOT NULL,
    upload_time timestamp without time zone NOT NULL,
    leeches smallint NOT NULL,
    seeders smallint NOT NULL,
    info_sha256 bytea NOT NULL,
    url text NOT NULL,
    is_legal boolean,
    size_in_bytes bigint,
    CONSTRAINT resource_leeches_check CHECK ((leeches >= 0)),
    CONSTRAINT resource_seeders_check CHECK ((seeders >= 0)),
    CONSTRAINT resource_size_in_bytes_check CHECK ((size_in_bytes > 0))
);


ALTER TABLE torrent.resource OWNER TO postgres;

--
-- Name: share; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.share (
    resource_id uuid NOT NULL,
    title character varying(256) NOT NULL,
    description character varying(512),
    uploader_id uuid NOT NULL,
    category character varying(10) NOT NULL
);


ALTER TABLE torrent.share OWNER TO postgres;

--
-- Name: uploader; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.uploader (
    id uuid NOT NULL,
    name character varying(50) NOT NULL,
    recently_active timestamp without time zone NOT NULL,
    first_logged_in timestamp without time zone NOT NULL,
    recently_used_ip inet NOT NULL,
    first_used_ip inet NOT NULL
);


ALTER TABLE torrent.uploader OWNER TO postgres;

--
-- Name: admin_example_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.admin_example_view AS
 SELECT s.title,
    s.category,
    resource.seeders,
    resource.leeches,
    resource.info_sha256,
    resource.is_legal,
    resource.size_in_bytes,
    resource.upload_time,
    u.name,
    u.first_used_ip,
    u.recently_used_ip,
    s.resource_id
   FROM ((torrent.share s
     JOIN torrent.resource ON ((resource.id = s.resource_id)))
     JOIN torrent.uploader u ON ((u.id = s.uploader_id)));


ALTER VIEW public.admin_example_view OWNER TO postgres;

--
-- Name: all_shares; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.all_shares AS
 SELECT s.title,
    s.category,
    resource.seeders,
    resource.leeches,
    resource.info_sha256,
    resource.is_legal,
    resource.size_in_bytes,
    resource.upload_time
   FROM ((torrent.share s
     JOIN torrent.resource ON ((resource.id = s.resource_id)))
     JOIN torrent.uploader ON ((uploader.id = s.uploader_id)));


ALTER VIEW public.all_shares OWNER TO postgres;

--
-- Name: resource; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.resource (
    id uuid NOT NULL,
    upload_time timestamp without time zone NOT NULL,
    leeches smallint NOT NULL,
    seeders smallint NOT NULL,
    info_sha256 bytea NOT NULL,
    url text NOT NULL,
    is_legal boolean,
    size_in_bytes bigint,
    CONSTRAINT resource_leeches_check CHECK ((leeches >= 0)),
    CONSTRAINT resource_seeders_check CHECK ((seeders >= 0)),
    CONSTRAINT resource_size_in_bytes_check CHECK ((size_in_bytes > 0))
);


ALTER TABLE public.resource OWNER TO postgres;

--
-- Name: film_archetype; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.film_archetype (
    id uuid NOT NULL,
    title character varying(256) NOT NULL,
    format character varying(256) NOT NULL,
    language_code character varying(2) NOT NULL,
    resolution character varying(9) NOT NULL,
    release_year character varying(4) NOT NULL,
    length_in_minutes smallint NOT NULL,
    CONSTRAINT film_archetype_length_in_minutes_check CHECK ((length_in_minutes > 0))
);


ALTER TABLE torrent.film_archetype OWNER TO postgres;

--
-- Name: film_instance; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.film_instance (
    share_id uuid NOT NULL,
    archetype_id uuid
);


ALTER TABLE torrent.film_instance OWNER TO postgres;

--
-- Name: share_movie_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.share_movie_details AS
 SELECT s.title AS share_title,
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
   FROM ((((torrent.share s
     JOIN torrent.resource r ON ((r.id = s.resource_id)))
     JOIN torrent.uploader u ON ((u.id = s.uploader_id)))
     JOIN torrent.film_instance fi ON ((fi.share_id = s.resource_id)))
     JOIN torrent.film_archetype fa ON ((fa.id = fi.archetype_id)));


ALTER VIEW public.share_movie_details OWNER TO postgres;

--
-- Name: suspicious_ips; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.suspicious_ips AS
 WITH all_ips_by_user AS (
         SELECT u.first_used_ip
           FROM torrent.uploader u
        UNION ALL
         SELECT u2.recently_used_ip
           FROM torrent.uploader u2
        )
 SELECT count(first_used_ip) AS count
   FROM all_ips_by_user
  WHERE (first_used_ip << '100.43.72.1/24'::inet);


ALTER VIEW public.suspicious_ips OWNER TO postgres;

--
-- Name: suspicious_urls_in_a_week; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.suspicious_urls_in_a_week AS
 SELECT id,
    upload_time,
    leeches,
    seeders,
    info_sha256,
    url,
    is_legal,
    size_in_bytes
   FROM torrent.resource r
  WHERE ((upload_time < (CURRENT_DATE - 7)) AND (url ~~ 'http://%'::text));


ALTER VIEW public.suspicious_urls_in_a_week OWNER TO postgres;

--
-- Name: uploader; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.uploader (
    id uuid NOT NULL,
    name character varying(50) NOT NULL,
    recently_active timestamp without time zone NOT NULL,
    first_logged_in timestamp without time zone NOT NULL,
    recently_used_ip inet NOT NULL,
    first_used_ip inet NOT NULL
);


ALTER TABLE public.uploader OWNER TO postgres;

--
-- Name: audio_book; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.audio_book (
    id uuid NOT NULL,
    studio character varying(256) NOT NULL,
    read_by character varying(256) NOT NULL,
    language_code character varying(2) NOT NULL,
    length_epoch smallint NOT NULL,
    format character varying(6) NOT NULL,
    release_year character varying(4) NOT NULL,
    source_book_id uuid NOT NULL,
    CONSTRAINT audio_book_length_epoch_check CHECK ((length_epoch > 0))
);


ALTER TABLE torrent.audio_book OWNER TO postgres;

--
-- Name: book_archetype; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.book_archetype (
    id uuid NOT NULL,
    title character varying(256) NOT NULL,
    author character varying(256) NOT NULL,
    language_code character varying(2) NOT NULL,
    isbn character varying(13) NOT NULL
);


ALTER TABLE torrent.book_archetype OWNER TO postgres;

--
-- Name: book_instance; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.book_instance (
    share_id uuid NOT NULL,
    archetype_id uuid
);


ALTER TABLE torrent.book_instance OWNER TO postgres;

--
-- Name: category; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.category (
    name character varying(10) NOT NULL
);


ALTER TABLE torrent.category OWNER TO postgres;

--
-- Name: ebook; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.ebook (
    id uuid NOT NULL,
    studio character varying(256) NOT NULL,
    format character varying(6) NOT NULL,
    release_year character varying(4) NOT NULL,
    source_book_id uuid NOT NULL
);


ALTER TABLE torrent.ebook OWNER TO postgres;

--
-- Name: game_archetype; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.game_archetype (
    id uuid NOT NULL,
    title character varying(256) NOT NULL,
    studio character varying(256) NOT NULL,
    language_code character varying(2) NOT NULL,
    release_year character varying(4) NOT NULL,
    operating_system character varying(10) NOT NULL
);


ALTER TABLE torrent.game_archetype OWNER TO postgres;

--
-- Name: game_instance; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.game_instance (
    share_id uuid NOT NULL,
    archetype_id uuid
);


ALTER TABLE torrent.game_instance OWNER TO postgres;

--
-- Name: music_archetype; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.music_archetype (
    id uuid NOT NULL,
    length_epoch smallint NOT NULL,
    format character varying(6) NOT NULL,
    album_name character varying(256) NOT NULL,
    release_year character varying(4),
    CONSTRAINT music_archetype_length_epoch_check CHECK ((length_epoch > 0))
);


ALTER TABLE torrent.music_archetype OWNER TO postgres;

--
-- Name: music_instance; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.music_instance (
    share_id uuid NOT NULL,
    archetype_id uuid
);


ALTER TABLE torrent.music_instance OWNER TO postgres;

--
-- Name: operating_system; Type: TABLE; Schema: torrent; Owner: postgres
--

CREATE TABLE torrent.operating_system (
    name character varying(10) NOT NULL
);


ALTER TABLE torrent.operating_system OWNER TO postgres;

--
-- Data for Name: resource; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes) FROM stdin;
\.


--
-- Data for Name: uploader; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.uploader (id, name, recently_active, first_logged_in, recently_used_ip, first_used_ip) FROM stdin;
\.


--
-- Data for Name: audio_book; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.audio_book (id, studio, read_by, language_code, length_epoch, format, release_year, source_book_id) FROM stdin;
5f462bc4-108c-40a5-9b39-f641ee472f47	Realcube	Colman Saberton	ge	1506	.wav	2001	4bb1787a-860c-48b1-9f74-8bb5ade1960b
62b28f4d-fbc3-4c1a-bf80-f940294b08af	Dabtype	Margy Herreran	fr	576	.wav	1997	21c4a9f0-ee8d-498c-bb69-0d57c60cfe6a
da5a9846-c175-4b61-8b6d-c0c46b21c101	Fanoodle	Brewer Thwaite	en	645	.wav	1984	162ef95c-51a1-467e-9582-3917f801ea3c
8920252a-6207-44b7-9325-c4667df55348	Dazzlesphere	Glendon O'Fihily	pl	1252	.wav	2004	e98a9590-45cb-4f60-8b69-86abe9d89878
bbe8bbc0-b4fe-460d-85da-0ea595daf64d	Yombu	Holly Gwilym	pl	1818	.wav	1991	2efe7e52-9774-4370-ac9d-9047c1b63e6a
f18984d7-4e2c-4688-840a-f7ca35f3158f	Flashspan	Leandra Olphert	fr	1655	.wav	2005	9e4f52b2-e11b-4b2a-811c-56445dd5645a
3be68b47-dc74-48d8-bc00-6305ae73fe76	Shuffledrive	Francis Gates	en	644	.wav	2003	3f22f0ad-c1f4-497d-ad4e-1a0c1514a9fa
abf7a51d-59df-4778-bc07-f597ab06c946	Twimbo	Hallie MacAne	en	1277	.wav	2010	1791a812-1c56-4bb5-9844-760929d9dc5d
a2317745-b193-4750-b2db-07c322ba9a88	Gabvine	Chen Pesselt	en	669	.wav	1994	3dc5346a-c3b7-4291-a2c4-47b434128d49
70f458c2-c41d-430a-88e0-1e1b10e5c523	Riffpath	Tamra Forshaw	fr	656	.mp3	2006	e6523651-5f32-444c-a18c-d9d3c0fee0f4
7c7962f7-f98b-4cdf-9f60-f7a056464628	Mynte	Bambi Armour	en	1661	.mp3	2009	8644278c-a906-446c-887b-5c0b59c9c76c
88a9fa15-fc73-413b-a75f-f41261fb9378	Npath	Anna-maria Petroselli	en	832	.wav	1992	544e28a7-1500-4b40-8f18-07491b1f8640
b7d550bb-2ae3-425f-b821-3a9c7433eb2e	Livetube	Wilow Simchenko	ge	693	.mp3	1991	de012a69-f9e3-4bc7-a626-662ebba742e6
fa31217a-102a-4ac4-9542-5ba7000c0950	Mydeo	Loretta Croix	en	1125	.wav	1963	99ceaaea-011e-4408-96d5-e15ad86ddd64
8182a436-4c9f-4447-afc3-932dfb9dc8f1	Twitterworks	Paddie Royste	en	1627	.wav	2007	c451c6fb-941a-4c5f-9a4f-3043334a9413
ece738b2-742f-486f-8433-f88d844030bc	Livefish	Risa Kaes	fr	1880	.wav	2009	aba2d338-97f5-4ef5-a501-075e1e2f465b
64876323-f4b4-43b4-912f-5275dda4457a	Edgeclub	Carena MacKenzie	fr	1553	.mp3	2006	44df134d-3f0f-4f72-b7f4-9f0a5455b222
6c57ebd6-a25d-4e21-863f-c9e4ef76ff0a	Buzzdog	Zedekiah Doppler	fr	1142	.wav	1998	657959d5-9b4e-45e5-bbdc-0559f97eaf03
1ee7a4a9-1294-4465-bc33-47d3d5647cd3	Skidoo	Stanfield Pattle	pl	2021	.mp3	2006	5c2611af-c926-4c72-8514-b70f483e6b52
ff9383d5-92d8-4c80-a9de-e81ca725324b	Meezzy	Fanny Blaydon	pl	1014	.wav	2006	53f3b7ff-01a3-4a1a-911c-335ebffc5052
a0ad4d57-986b-4b96-92b5-97eb08302808	Brainbox	Editha Kaley	en	337	.mp3	1990	80608b32-8bc2-40be-b1c6-4dc9b9508cf5
c49f72c1-8262-4cbb-9250-256848a879fd	Minyx	Nicko Sherred	en	1985	.wav	1999	fe9157be-bd38-4f8c-a716-435f1eda513f
90f5503b-1475-4995-9c7a-3c2bf6ce2646	Wordify	Della Tuke	en	2119	.wav	2006	29c461a2-3f3c-46d6-9ad0-5d68d2486a90
3d4bf514-da06-4288-8c8b-2fbada786534	Latz	Kristal Capp	fr	42	.mp3	1996	8a257c2c-921e-4f20-84d6-72fcb3a32180
7e4be389-86f7-4a68-8cbf-62b38be38073	Tambee	Philis Iacopetti	pl	754	.mp3	1998	2ddb295c-4830-4923-8781-ebabe3443655
b0ae7e91-66cf-41e7-89dd-db26cca4bc52	Meeveo	Betsey Naptin	en	1509	.wav	2007	83110150-d0b7-4b2d-861e-445be94dcef6
f937c1a2-166d-4b5e-9341-ab133ad4fb69	Divanoodle	Sanderson Hearnaman	ge	1645	.wav	1993	f0dd3846-c2c6-400d-bc02-3fd7c90574e8
66e54bca-00be-4b97-8bc8-6c690ce393e2	Camimbo	Jephthah Rupp	ge	1635	.mp3	2011	58786a57-488c-4413-83be-f336e5c4afd4
bf81fa80-33da-4d31-8c8a-1afe5fc4df60	Devify	Alina Bodle	ge	74	.mp3	1991	b7757055-4c52-4e96-8627-22c543c32506
d643adb7-f649-4466-a0fa-90b18132ce51	Nlounge	Aleta Seear	ge	1479	.wav	2001	8f6cbe56-ac88-4449-9a77-6bad5467e17a
235fab13-3058-4a7e-a226-c0428d22d40f	Fliptune	Justino Silverson	ge	1707	.mp3	2012	a33e114b-2159-49c4-9e21-b81a03d13e50
0a2dca0e-6c4f-4156-b768-9d4dcdc2a4b4	Flipopia	Benny McAllan	ge	1680	.wav	2012	c6664e4b-f4e5-4d25-a306-6ff9c40b1842
5db69f55-efc4-457f-a317-021e8257e740	Jamia	Harriet Lorey	ge	890	.wav	2004	a662c1cb-0d04-4623-9266-140099f38898
030f5d43-39fa-4bca-a38c-3b2c7b45379a	Oloo	Brook Gleasane	fr	1655	.mp3	2001	68d7bed1-aa47-4524-b2d4-5ef241e39fc3
cdad20c6-902b-4295-9d20-332d11209d74	Vitz	Christiane Rix	en	1337	.wav	2001	cedb897b-2806-4645-9afd-4c75f8091a5a
90a30e12-7ae1-4315-a13f-8114bd5b5c36	Pixoboo	Sallee Fincken	en	1422	.mp3	1990	4e569d36-adeb-4b6b-a832-d2127db5f4e8
55dbeef0-55d8-4ff2-8896-08aca53b0f7b	Cogidoo	Fiona Summerlie	ge	269	.wav	2008	7169967d-aa2b-4778-aaeb-0148cc53d928
511752dc-4127-4a39-96ca-3334295c540a	Zoombeat	Denney Pellamonuten	en	1915	.wav	2007	d2c26657-4f39-4e57-ac50-0e84cca19116
e2302b92-f8b8-4954-b6f7-5ed3bfc8ff93	Myworks	Valina Griswood	fr	409	.mp3	1997	65378cad-96ab-4c06-8384-90967c29bf23
b2293983-6505-4f22-a251-f891fd379a94	Browsetype	Cortie Ong	ge	2069	.wav	2005	521b5ca4-a609-4583-9c73-4ad6f9165ddb
2de218eb-000d-40db-b5af-cbca16a00592	Youfeed	Merrill McLice	en	1858	.mp3	1988	0a8dbff1-e874-4e3b-b316-6d3e0cc89a90
09d9705a-7a3c-4e9b-8211-23413eaf6645	Zoomlounge	Glyn Gristock	en	444	.mp3	2002	f83a4b03-2bea-4933-89e5-9f0fe8a28de0
0fe9218a-bf89-4c0f-b96d-c6506006e614	Mycat	Arman McVicker	ge	1655	.wav	2000	4efb224f-9b2d-4722-8613-b34b23cb174a
83af63d9-051a-47b0-be9b-9016bf0ed94c	Dabfeed	Peirce Price	en	1235	.mp3	2007	685521d0-b13a-4125-9e23-372add1c2154
26a5b963-bb08-4446-b5df-24093650bb3e	Tagcat	Carol-jean Beardsley	en	920	.wav	2006	8a2a21ed-8ff5-40d3-a581-fb65fd936362
d99f8ea4-8348-4061-aa8c-f01a66d3992d	Yoveo	Ula Gehrtz	en	755	.wav	1991	b93abdea-ccb9-4069-b026-5c0ecfbf8c25
d247bb08-daff-4042-b15c-51dea338536f	Kare	Derwin Smail	fr	805	.mp3	2000	7203f61a-bf45-42f3-9e46-a46300b904f9
6da538d8-d2fe-400b-ac23-e3a6c430866c	Jetpulse	Morten Bodocs	en	2044	.mp3	1991	b13eac94-8c36-430b-ab62-2665a1d38dd4
14b209f0-ea77-4053-9707-691c35f4a355	Photofeed	Abigail Rayer	pl	1116	.wav	2012	8fbe1271-9c89-4373-baa8-976bdebf9660
64925c20-a42d-4cdd-8f37-78475412d6c4	Skipstorm	Roberta Leftley	fr	1943	.wav	2008	d70fb665-c35e-4609-ada8-7b47a9d6a819
\.


--
-- Data for Name: book_archetype; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.book_archetype (id, title, author, language_code, isbn) FROM stdin;
21c4a9f0-ee8d-498c-bb69-0d57c60cfe6a	Greenlam	Tiffy Hames	fr	901233093-9
4bb1787a-860c-48b1-9f74-8bb5ade1960b	Cardguard	Jaime Silman	en	484464667-2
162ef95c-51a1-467e-9582-3917f801ea3c	Home Ing	Kaile Connop	ge	808639290-2
e98a9590-45cb-4f60-8b69-86abe9d89878	Andalax	Linzy Jeune	pl	713985242-1
2efe7e52-9774-4370-ac9d-9047c1b63e6a	Viva	Gideon Feronet	ge	806444063-7
9e4f52b2-e11b-4b2a-811c-56445dd5645a	Greenlam	Moll Coltherd	ge	381569632-1
3f22f0ad-c1f4-497d-ad4e-1a0c1514a9fa	Alphazap	Darcy Quant	en	353534812-9
1791a812-1c56-4bb5-9844-760929d9dc5d	Bigtax	Krystalle Pougher	fr	336952794-4
3dc5346a-c3b7-4291-a2c4-47b434128d49	Temp	Ingrim Pischel	fr	825099487-6
e6523651-5f32-444c-a18c-d9d3c0fee0f4	Ventosanzap	Leanna Symcock	ge	761038501-8
8644278c-a906-446c-887b-5c0b59c9c76c	Asoka	Vince Ughi	fr	881705807-6
544e28a7-1500-4b40-8f18-07491b1f8640	Domainer	Wyn Lacrouts	en	693682272-X
de012a69-f9e3-4bc7-a626-662ebba742e6	Quo Lux	Jenn Arling	ge	074601899-1
99ceaaea-011e-4408-96d5-e15ad86ddd64	Bitchip	Teresita Benterman	pl	280111408-1
c451c6fb-941a-4c5f-9a4f-3043334a9413	Cardguard	Beaufort Brach	fr	235436076-2
aba2d338-97f5-4ef5-a501-075e1e2f465b	Stronghold	Rozalie Skeldinge	ge	502104110-X
44df134d-3f0f-4f72-b7f4-9f0a5455b222	Duobam	Palmer Seleway	fr	059032230-3
657959d5-9b4e-45e5-bbdc-0559f97eaf03	Hatity	Loy Coggon	en	635461818-6
5c2611af-c926-4c72-8514-b70f483e6b52	Hatity	Trenna Flott	en	407443793-7
53f3b7ff-01a3-4a1a-911c-335ebffc5052	Sonsing	Eran Hamberston	pl	707738446-2
80608b32-8bc2-40be-b1c6-4dc9b9508cf5	Bigtax	Dorie Ruppertz	fr	898676486-5
fe9157be-bd38-4f8c-a716-435f1eda513f	Regrant	Bunny MacKim	ge	207138907-7
29c461a2-3f3c-46d6-9ad0-5d68d2486a90	Zamit	Deni Errichi	en	672093119-9
8a257c2c-921e-4f20-84d6-72fcb3a32180	Tampflex	Cati Sotham	ge	909495201-7
2ddb295c-4830-4923-8781-ebabe3443655	Toughjoyfax	Olivette Spanton	pl	399170187-1
83110150-d0b7-4b2d-861e-445be94dcef6	Zontrax	Leigh Emlyn	en	214496846-2
f0dd3846-c2c6-400d-bc02-3fd7c90574e8	Temp	Mozes Woodwin	pl	891340963-1
58786a57-488c-4413-83be-f336e5c4afd4	Zaam-Dox	Gonzales Hildred	fr	149152115-5
b7757055-4c52-4e96-8627-22c543c32506	Lotlux	Sandro Jahn	pl	901083049-7
8f6cbe56-ac88-4449-9a77-6bad5467e17a	Konklab	Cullan Manktelow	pl	347813835-3
a33e114b-2159-49c4-9e21-b81a03d13e50	Konklab	Claudine Lugard	ge	628815546-2
c6664e4b-f4e5-4d25-a306-6ff9c40b1842	Sonair	Sheilah Donn	fr	091292811-5
a662c1cb-0d04-4623-9266-140099f38898	Bitwolf	Daryl Haskey	pl	013333474-0
68d7bed1-aa47-4524-b2d4-5ef241e39fc3	Konklux	Kendra Tolotti	fr	553482200-7
cedb897b-2806-4645-9afd-4c75f8091a5a	Bigtax	Abbot Missington	fr	110490166-8
4e569d36-adeb-4b6b-a832-d2127db5f4e8	Treeflex	Kali Grimm	en	924427531-7
7169967d-aa2b-4778-aaeb-0148cc53d928	Vagram	Filippo Rowntree	ge	593973476-6
d2c26657-4f39-4e57-ac50-0e84cca19116	Gembucket	Ketty Chander	fr	576027602-6
65378cad-96ab-4c06-8384-90967c29bf23	Overhold	Barbabas Gibb	en	119755996-5
521b5ca4-a609-4583-9c73-4ad6f9165ddb	Konklab	Flossy Bygreaves	ge	277181697-0
0a8dbff1-e874-4e3b-b316-6d3e0cc89a90	Keylex	Griffie Marchello	en	821476138-7
f83a4b03-2bea-4933-89e5-9f0fe8a28de0	Lotlux	Crawford McIlvaney	en	425774355-7
4efb224f-9b2d-4722-8613-b34b23cb174a	Temp	Bonny Matherson	fr	945263296-8
685521d0-b13a-4125-9e23-372add1c2154	Transcof	Shellysheldon Gyves	en	411874588-7
8a2a21ed-8ff5-40d3-a581-fb65fd936362	Home Ing	Nanci Choake	ge	703290064-X
b93abdea-ccb9-4069-b026-5c0ecfbf8c25	Quo Lux	Ashley Labba	en	367978115-6
7203f61a-bf45-42f3-9e46-a46300b904f9	Cardguard	Winn Joddens	en	636460177-4
b13eac94-8c36-430b-ab62-2665a1d38dd4	Stronghold	Emlynne Mayhead	ge	632407135-9
8fbe1271-9c89-4373-baa8-976bdebf9660	Stim	Gretna Hurdwell	pl	711002768-6
d70fb665-c35e-4609-ada8-7b47a9d6a819	Overhold	Alleen Fryers	en	410294126-6
\.


--
-- Data for Name: book_instance; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.book_instance (share_id, archetype_id) FROM stdin;
b87992d0-07e8-4722-a46c-0c485531769a	21c4a9f0-ee8d-498c-bb69-0d57c60cfe6a
abed90de-e6e3-41bb-8fec-d87ae1f22c7b	4bb1787a-860c-48b1-9f74-8bb5ade1960b
bee827f7-153f-4ea6-8560-c56c457a6dd8	162ef95c-51a1-467e-9582-3917f801ea3c
9d049c58-229d-4ec8-9cdb-162b0d9f9345	e98a9590-45cb-4f60-8b69-86abe9d89878
1ebdf3ce-e494-4c3e-a790-c86bc08e4d67	2efe7e52-9774-4370-ac9d-9047c1b63e6a
43619229-320c-46b5-bbac-a4f471d08dfc	9e4f52b2-e11b-4b2a-811c-56445dd5645a
d9071722-e23b-43c2-aa3e-1c8b94bf7366	3f22f0ad-c1f4-497d-ad4e-1a0c1514a9fa
b630349e-cc0e-47d8-a114-833fc730ffb1	1791a812-1c56-4bb5-9844-760929d9dc5d
57f85f07-3b26-4caf-9ed1-2092cb1fbd34	3dc5346a-c3b7-4291-a2c4-47b434128d49
79979547-c11c-4ca7-9da7-002458c9684b	e6523651-5f32-444c-a18c-d9d3c0fee0f4
4c79c51d-e1a6-4e33-989b-91922db093ec	8644278c-a906-446c-887b-5c0b59c9c76c
e37aeab6-1be7-4fc8-94c1-684e258e660e	544e28a7-1500-4b40-8f18-07491b1f8640
ad2f05a2-99df-499b-9b37-77fd9c74a1e3	de012a69-f9e3-4bc7-a626-662ebba742e6
209f41e4-52eb-4829-94d2-c158e91cba6b	99ceaaea-011e-4408-96d5-e15ad86ddd64
2064a42d-f721-4aef-b6f0-a2bab04d2c3c	c451c6fb-941a-4c5f-9a4f-3043334a9413
d27970ba-5356-4532-9cdf-ab2157ff671b	aba2d338-97f5-4ef5-a501-075e1e2f465b
dec1f80b-9bd4-4570-8f22-df2cf57c039e	44df134d-3f0f-4f72-b7f4-9f0a5455b222
9d88c2b5-fadd-4242-ad5f-d7996683a487	657959d5-9b4e-45e5-bbdc-0559f97eaf03
fac7e88a-d9ca-474e-a165-a490faa20515	21c4a9f0-ee8d-498c-bb69-0d57c60cfe6a
f5c6f0f2-36ba-4217-8b47-07e79ccc357a	4bb1787a-860c-48b1-9f74-8bb5ade1960b
de2adefd-7799-4a41-b0b5-443c11fa046e	162ef95c-51a1-467e-9582-3917f801ea3c
d5c9cd40-e0d2-4d29-8cb0-c16ac6e0c4aa	e98a9590-45cb-4f60-8b69-86abe9d89878
ce6f1627-5a01-4644-87fa-cac6dca8d158	2efe7e52-9774-4370-ac9d-9047c1b63e6a
b0313dd5-9ba5-4cca-84d9-85a4ad0158c6	9e4f52b2-e11b-4b2a-811c-56445dd5645a
a112fd46-a09e-4523-8baf-0bf93e9174c2	3f22f0ad-c1f4-497d-ad4e-1a0c1514a9fa
8d9c11e6-678e-41f8-b4bb-5e61bf917c03	1791a812-1c56-4bb5-9844-760929d9dc5d
71b8026a-3596-4d44-bc8e-7f9bdf6e4942	3dc5346a-c3b7-4291-a2c4-47b434128d49
58c1b148-513c-4319-b08a-385f12befe47	e6523651-5f32-444c-a18c-d9d3c0fee0f4
51c760af-1888-4309-b28c-6c72ba43c5a7	8644278c-a906-446c-887b-5c0b59c9c76c
44e60dc6-4808-4933-aa49-d0eaf18138e9	544e28a7-1500-4b40-8f18-07491b1f8640
3b85e730-fa0d-4f46-ab5b-9aeeb85ea27d	de012a69-f9e3-4bc7-a626-662ebba742e6
388853e4-b20d-4200-9ced-f26e7fe20f32	99ceaaea-011e-4408-96d5-e15ad86ddd64
36c1a79a-a65e-4474-8ffa-8f8e0355b99d	c451c6fb-941a-4c5f-9a4f-3043334a9413
275a4db2-d27e-4a05-9537-424932af3e1c	aba2d338-97f5-4ef5-a501-075e1e2f465b
22fb047a-a258-4976-9d59-26c0e5e3432a	44df134d-3f0f-4f72-b7f4-9f0a5455b222
16866ac4-7745-4e27-a72c-70c9031e58cb	657959d5-9b4e-45e5-bbdc-0559f97eaf03
068cde22-250b-4310-8298-2f07a2f28e58	5c2611af-c926-4c72-8514-b70f483e6b52
05cf44ed-c3fb-412f-8d9a-06528f1c6b90	53f3b7ff-01a3-4a1a-911c-335ebffc5052
\.


--
-- Data for Name: category; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.category (name) FROM stdin;
film
ebook
audiobook
music
game
\.


--
-- Data for Name: ebook; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.ebook (id, studio, format, release_year, source_book_id) FROM stdin;
51727bbd-14ff-4fd9-b9cb-5fd584c6e22c	Walsh LLC	.azw	2004	21c4a9f0-ee8d-498c-bb69-0d57c60cfe6a
09f9af19-6cd5-41da-8004-a79d67d07c13	Macejkovic and Sons	.awz3	1992	4bb1787a-860c-48b1-9f74-8bb5ade1960b
2990f339-fb02-418f-ba28-703f462146e1	Cronin-Schowalter	.azw	1965	162ef95c-51a1-467e-9582-3917f801ea3c
f65bd9cb-f867-49a4-9934-c192b5337ab6	Trantow LLC	.awz3	2011	e98a9590-45cb-4f60-8b69-86abe9d89878
7abdc9b9-ec03-47a2-a1cf-df78ee7e6a78	Effertz LLC	.mobi	1994	2efe7e52-9774-4370-ac9d-9047c1b63e6a
626b6546-2c75-4103-a308-07c17540ad0d	Kerluke-Stroman	.awz3	2000	9e4f52b2-e11b-4b2a-811c-56445dd5645a
a39e156f-2eb7-452c-a13e-dd378564ff98	Murazik-Hyatt	.awz3	1963	3f22f0ad-c1f4-497d-ad4e-1a0c1514a9fa
d5a88da0-7e80-4c6c-a09c-c5bfe84ecd1f	Medhurst, Gerlach and Hegmann	.awz3	2000	1791a812-1c56-4bb5-9844-760929d9dc5d
41e96cdb-1d2e-477b-a672-7d426079ad12	Hane Group	.pdf	1989	3dc5346a-c3b7-4291-a2c4-47b434128d49
71a0449c-107a-4bd3-afc1-138f697c1430	Hegmann Inc	.mobi	1993	e6523651-5f32-444c-a18c-d9d3c0fee0f4
0b48a56e-2c52-4e1b-8f3e-715cec9e3200	D'Amore-Quitzon	.awz3	2009	8644278c-a906-446c-887b-5c0b59c9c76c
2b9a160e-c514-4862-9941-c709324ecb87	Frami-Stark	.awz3	1992	544e28a7-1500-4b40-8f18-07491b1f8640
4ecbf96c-6787-48ef-8ea4-d6949523729d	Nicolas, Durgan and Ritchie	.azw	2002	de012a69-f9e3-4bc7-a626-662ebba742e6
a9b69812-2daf-4b55-86bb-010c500ed53e	Johns-Heathcote	.azw	2012	99ceaaea-011e-4408-96d5-e15ad86ddd64
2fc33943-5280-4f62-a320-f4fba23eb9a9	Armstrong-Bauch	.awz3	1985	c451c6fb-941a-4c5f-9a4f-3043334a9413
49477644-a902-4b74-9d46-e1505dec8dc9	Huel, Blanda and Aufderhar	.pdf	2012	aba2d338-97f5-4ef5-a501-075e1e2f465b
6abc9dff-e9a9-4510-8dbd-4dd9dd2d9a67	Mraz-Mann	.awz3	1996	44df134d-3f0f-4f72-b7f4-9f0a5455b222
8df2c2c8-4b48-4df5-bef7-1cb882296882	Rohan-Reichert	.pdf	2006	657959d5-9b4e-45e5-bbdc-0559f97eaf03
24d36b27-c531-4d65-a7ca-5c6bb35830e3	Schmidt-Renner	.pdf	1993	5c2611af-c926-4c72-8514-b70f483e6b52
ead82bce-7bb0-4aa0-895e-e7d8f66ae6db	Steuber, Jast and Bauch	.azw	2010	53f3b7ff-01a3-4a1a-911c-335ebffc5052
914319fe-fd44-40b6-b81c-dca04649724a	Kuhlman, Rau and Mann	.pdf	2010	80608b32-8bc2-40be-b1c6-4dc9b9508cf5
d40e7594-d86b-40e0-99ca-ecd6313b55ad	Schamberger and Sons	.pdf	1994	fe9157be-bd38-4f8c-a716-435f1eda513f
15b41495-75ff-4189-b376-f569e8d47f4e	Keebler and Sons	.azw	2010	29c461a2-3f3c-46d6-9ad0-5d68d2486a90
89b280e8-f00d-4a2e-b214-b07b3331126f	Cronin Group	.mobi	2005	8a257c2c-921e-4f20-84d6-72fcb3a32180
1b8f0aa4-0b2f-4641-99be-badb26f66888	Kohler Inc	.awz3	1997	2ddb295c-4830-4923-8781-ebabe3443655
575f835d-ca77-42a6-888c-3a0d164c1e66	McLaughlin, Ebert and Stoltenberg	.awz3	2005	83110150-d0b7-4b2d-861e-445be94dcef6
a9f78174-8b09-403f-b4da-b7ea9879bb91	Howell-Hegmann	.pdf	1989	f0dd3846-c2c6-400d-bc02-3fd7c90574e8
8d2bfdcf-d139-4537-afd5-8dfecc24ae41	Moore, Lubowitz and Streich	.pdf	1999	58786a57-488c-4413-83be-f336e5c4afd4
96350ae4-458e-4ee1-a6f6-b6023f4688dc	Kohler LLC	.pdf	1990	b7757055-4c52-4e96-8627-22c543c32506
c32da795-c09d-4834-8ab2-f7dd37c15f6d	Smitham and Sons	.azw	1998	8f6cbe56-ac88-4449-9a77-6bad5467e17a
fa9627d6-9a87-4c96-b0c5-1dafb15ef94a	Boehm, Kautzer and Herzog	.pdf	1987	a33e114b-2159-49c4-9e21-b81a03d13e50
b1bd7718-be10-40f9-9b01-3b7d97de326a	Rempel-Douglas	.azw	1987	c6664e4b-f4e5-4d25-a306-6ff9c40b1842
145ffd6a-9d51-47a1-a82b-eade0288a3bc	Baumbach and Sons	.awz3	1988	a662c1cb-0d04-4623-9266-140099f38898
d24f7a10-c7a3-4e7a-b0e8-e8f491913ab6	Bartoletti and Sons	.mobi	2010	68d7bed1-aa47-4524-b2d4-5ef241e39fc3
c4741765-0312-47b9-906c-d3c7cf0663f5	Kuhic, Hoppe and Schmidt	.awz3	2002	cedb897b-2806-4645-9afd-4c75f8091a5a
a43cb3b5-00d5-47d8-b59a-ff309d6df9e9	Gibson-Rippin	.awz3	2006	4e569d36-adeb-4b6b-a832-d2127db5f4e8
5891df2e-c768-4896-88b3-9ca332f016d1	Schuster, Hermiston and Jakubowski	.pdf	2006	7169967d-aa2b-4778-aaeb-0148cc53d928
e8a69741-6b7e-45ec-bcea-4ea1e9f7f4b0	Donnelly Group	.pdf	2012	d2c26657-4f39-4e57-ac50-0e84cca19116
d3c217cf-6e54-4e2d-a741-70dd0e79c221	Kuvalis-Schmidt	.pdf	1985	65378cad-96ab-4c06-8384-90967c29bf23
3e7c25ab-decf-4d9c-87ac-9cd792aba20e	Blanda-Conn	.mobi	2010	521b5ca4-a609-4583-9c73-4ad6f9165ddb
75f88e89-a7c4-466e-98f5-e3e730e76e1d	Kunze-O'Connell	.azw	2004	0a8dbff1-e874-4e3b-b316-6d3e0cc89a90
03ecf46b-b269-40e1-9873-8b6f07e82f1b	Smith-Towne	.awz3	2004	f83a4b03-2bea-4933-89e5-9f0fe8a28de0
0b013823-be88-4fd1-9b33-c8b9635718b2	Nicolas-Wisozk	.awz3	1996	4efb224f-9b2d-4722-8613-b34b23cb174a
0cd972b9-1782-4ddf-8dab-f222bce805d1	Mitchell LLC	.awz3	2000	685521d0-b13a-4125-9e23-372add1c2154
dceff44a-c547-494f-952e-37ab44a3d845	Ernser Group	.pdf	1997	8a2a21ed-8ff5-40d3-a581-fb65fd936362
6433c6be-f161-482d-9cae-cc9e0cc6e952	Lang-Russel	.pdf	2006	b93abdea-ccb9-4069-b026-5c0ecfbf8c25
9c7716b4-010b-4562-b54f-44985af09193	Walker, McKenzie and Wilkinson	.mobi	1997	7203f61a-bf45-42f3-9e46-a46300b904f9
6d6ee50e-6c06-448e-9bb7-8854ef03df94	Heathcote, Bradtke and Carroll	.awz3	1997	b13eac94-8c36-430b-ab62-2665a1d38dd4
8f11c504-db56-4668-9ca8-ff5877fc1e53	Bergnaum Group	.awz3	1994	8fbe1271-9c89-4373-baa8-976bdebf9660
c9f7d917-20e2-4578-af92-6df7d59aeb2d	Tremblay, Pollich and Okuneva	.awz3	2009	d70fb665-c35e-4609-ada8-7b47a9d6a819
\.


--
-- Data for Name: film_archetype; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.film_archetype (id, title, format, language_code, resolution, release_year, length_in_minutes) FROM stdin;
aa10bb10-362e-4f0b-a7e5-750a7357ad87	Saint of Fort Washington, The	.mp4	ge		2011	168
04734a79-d1f5-44ce-9bd2-437b8695bfa3	Damned, The (Les Maudits)	.dvd	ir		1996	64
ee61266a-4b64-429b-802c-bedf811dc256	Ten Seconds to Hell	.iso	en		2002	9
29fcc732-f021-496c-8195-44ff12d3a031	Bleeding House, The	.iso	ir		2012	49
82bdb1d4-0bd8-459b-96db-1742b0b824a5	Shriek If You Know What I Did Last Friday the Thirteenth	.iso	ir	2k	1999	16
dcc8bda1-0be4-4457-88bb-d3a276c74cd9	Humanoids from the Deep	.dvd	en		2001	144
32da9c5e-a63c-434e-aa7c-6126b718e0bf	Penalty, The	.flac	en	4k	2003	30
37c67b50-9a36-4da1-bc7d-2f77fe135a8d	Vesku from Finland (Vesku)	.flac	ir	1920x1080	2012	163
19eb6c67-dfef-47b3-862e-7f516ae95609	Freakonomics	.dvd	fr	1920x1080	2004	37
1bb600e4-eb08-451e-9838-865e672ee932	Louise Bourgeois: The Spider, the Mistress and the Tangerine	.flac	pl	4k	1986	6
b352272c-8748-41a9-a985-23b50e6de05d	Leatherheads	.dvd	ge	4k	2005	179
76fd5b66-4ad8-44fa-b57b-230324461f7a	Life Is Hot in Cracktown	.iso	en	4k	2007	90
a05af301-e588-488e-8c6f-d4771589dbac	Coward, The (Kapurush)	.mp4	en		2005	74
aa97cbd1-cf07-4b25-a9a7-bf41ecd0b026	Desk Set	.iso	ir	2k	2009	48
303ba078-a31e-4fb3-abcc-75a84cd807a2	In the Army Now	.iso	fr	2k	1986	128
907a6375-5189-4576-956e-2220e121bb6b	Rebirth	.mp4	pl	2k	2005	118
c183a38e-a455-47df-8b7c-0a0e26b4849d	Asterix & Obelix: Mission Cleopatra (Astérix & Obélix: Mission Cléopâtre)	.mp4	ir	1920x1080	2003	171
f49772f5-d271-48c2-aad5-d45f07257ab0	Starcrash (a.k.a. Star Crash)	.flac	ge	1920x1080	2013	86
b2bbd031-8eb3-4c8d-ae93-e7e2f8f2a1f1	Savages	.iso	fr	2k	1998	40
8df37283-e4ce-4e55-9a6f-41a2e83c9e71	Omen, The	.iso	fr	1920x1080	1993	88
4dc45637-cc5a-4a81-970c-a9aabcff47b4	My Prairie Home	.mp4	en	1920x1080	2010	56
6a5c9164-742f-40d8-bdfd-ef6527d4d9f1	Melody Time	.mp4	pl		1999	170
35a1dc7e-3bbf-47dd-9414-20e288a97617	Nighthawks	.flac	ir	2k	1993	113
949eb50b-a151-46f3-9ed1-cabbe9edd4d9	Nada Gang, The (Nada)	.flac	pl	4k	2008	24
0517d150-75f6-4cf6-98de-5b2a43f1b879	Brothers Lionheart, The (Bröderna Lejonhjärta)	.mp4	ir	4k	1996	151
95808637-c169-4383-8eaa-072332ab907f	Devil Wears Prada, The	.iso	pl	2k	1994	125
e8e53402-4004-445c-b4bb-9303dbe47d4b	Descent: Part 2, The	.flac	pl	2k	1989	86
ecd7d9ac-b5b9-4bf5-a32c-3f37aa276533	Dracula Has Risen from the Grave	.iso	en	1920x1080	2008	5
a20955d8-4229-45d7-bac9-f0b276023c78	Cohen and Tate	.iso	ir		1997	42
c0b3c048-219c-42b4-8670-bb7470b77283	Buffalo Bill and the Indians, or Sitting Bull's History Lesson (a.k.a. Buffalo Bill and the Indians)	.flac	ge	4k	2000	46
bebb7812-9f4a-4508-8f24-ff7579506471	Pajeczarki	.mp4	fr	2k	1995	177
1a1d9e05-7160-40a9-9865-29588abde9a9	P2	.flac	pl	1920x1080	2011	32
fab36e3a-b71a-4ed1-b815-58bbe31d50c2	Education of Mohammad Hussein, The	.flac	ge		1997	13
0e484fec-9585-4ef8-b9c2-1c10e1018835	Sound of Fury, The	.dvd	pl	4k	2012	40
90583841-bf7b-4929-aaba-5e8f4549485e	Sniper 2	.dvd	pl		1996	59
f5089a9a-f0be-4219-b643-a9834e90607b	Kaksi kotia (Dagmamman)	.dvd	en	4k	2002	45
f0bfa84d-158d-4bd1-845e-cfc9c3272435	My Best Friend's Wife	.mp4	ir		1983	51
31199ff1-1bbe-4ba8-9846-a034cfa6c779	Gymnast, The	.dvd	en	2k	1985	92
67f79b02-7d91-4c58-b6ca-572906416459	Savior	.flac	ge	1920x1080	1999	63
7428f00a-e185-40b4-9666-4200224767c0	Tremors 3: Back to Perfection	.flac	ge	1920x1080	1996	95
e41095cc-2b4b-413a-a3e0-7b9d0aff67e1	Baron Blood (Orrori del castello di Norimberga, Gli)	.mp4	ir		2011	76
9ec06388-e781-4eef-9b8d-6f422960f0a6	Lawless Frontier, The	.flac	pl	2k	1969	39
60ea09b4-9f4c-41b9-9d8c-a526cf0fca89	Trail of the Pink Panther	.dvd	pl		1986	153
0a29e6f7-29b1-489d-a990-0533c0821a1b	First Family	.iso	pl	2k	2011	58
803a4cb6-777b-4d4e-81d8-fa06959e05b7	Goodbye Again	.flac	fr	2k	1985	165
a047e16d-0eaf-4599-bbea-ddc2187c8bc6	Now!	.dvd	pl	4k	1993	99
b8cd989b-5c21-43b9-af89-d85fb021c05f	True Confessions	.iso	ge		2007	39
2b336859-01e3-4bb7-9535-1f1c0fc9a237	Michael Shayne: Private Detective	.dvd	fr	1920x1080	1991	95
09c96644-47c2-47b7-893e-f1f6dc54521f	Apartment 1303 3D	.iso	fr		1997	6
1943be96-abf3-43f9-8b42-0c3b01068453	Star Is Born, A	.flac	ir	2k	1992	22
\.


--
-- Data for Name: film_instance; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.film_instance (share_id, archetype_id) FROM stdin;
4c4cd997-bc95-411a-b536-0d80bbb32276	aa10bb10-362e-4f0b-a7e5-750a7357ad87
2731312a-5a85-48bd-88cc-613e00777a74	04734a79-d1f5-44ce-9bd2-437b8695bfa3
c7a5009c-2ae5-44c5-afb5-bf64c46fe26c	ee61266a-4b64-429b-802c-bedf811dc256
258dc54d-1b37-4100-84ce-b73b82a9a5f8	29fcc732-f021-496c-8195-44ff12d3a031
9f527479-34d3-423c-875b-a20c88bab7f1	82bdb1d4-0bd8-459b-96db-1742b0b824a5
cb7b5a74-07c7-4102-8c1f-01578e5bd65e	dcc8bda1-0be4-4457-88bb-d3a276c74cd9
19678a34-e91d-4103-b576-9474d67ea982	32da9c5e-a63c-434e-aa7c-6126b718e0bf
69ae4d80-9136-460f-b1c5-abf34cdd1cb5	37c67b50-9a36-4da1-bc7d-2f77fe135a8d
316fde0d-1a48-48e5-adea-76d3e21525bb	19eb6c67-dfef-47b3-862e-7f516ae95609
3fd3ebf8-5f0e-4f81-82ac-4093890c7db0	1bb600e4-eb08-451e-9838-865e672ee932
b4d53818-aefd-4c80-bf50-dae0a23bc41f	b352272c-8748-41a9-a985-23b50e6de05d
e7c10140-11fd-4181-b382-ff4101340373	76fd5b66-4ad8-44fa-b57b-230324461f7a
d1e5f0c9-6cab-43de-ba2c-bb7d59270c31	a05af301-e588-488e-8c6f-d4771589dbac
6fdc1e11-0f32-4d07-98ba-93573b3f524c	aa97cbd1-cf07-4b25-a9a7-bf41ecd0b026
47a15f21-a98f-494d-9ee4-014f46e06893	303ba078-a31e-4fb3-abcc-75a84cd807a2
5351c391-372f-46a4-83ce-85aaea7742b7	907a6375-5189-4576-956e-2220e121bb6b
2ccc2b6e-e152-4eb5-b58f-8b632aaca1dd	c183a38e-a455-47df-8b7c-0a0e26b4849d
152e7e81-3c4b-440b-b507-e46da6c4ab0e	f49772f5-d271-48c2-aad5-d45f07257ab0
c69d5f1d-a59e-41ca-b74f-8e93b9ec41a2	b2bbd031-8eb3-4c8d-ae93-e7e2f8f2a1f1
60bbcf26-410d-4789-a7a6-6ac0a4dee73a	8df37283-e4ce-4e55-9a6f-41a2e83c9e71
14f487d9-83d7-4ff7-887a-cde148b35cab	4dc45637-cc5a-4a81-970c-a9aabcff47b4
810fa726-a209-42fd-b90f-34a850e6b77e	6a5c9164-742f-40d8-bdfd-ef6527d4d9f1
\.


--
-- Data for Name: game_archetype; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.game_archetype (id, title, studio, language_code, release_year, operating_system) FROM stdin;
9e4858ce-70e3-4a35-9d4a-ca67ed0c8d24	Bamity	Skidoo	pl	2002	Windows 11
35932c93-b4ed-49ed-807a-d532fe4fcaf9	Zathin	Jabbercube	ge	2007	Windows 11
cff3df96-0530-4570-b435-d59d5b90d289	Tempsoft	Mycat	fr	1992	Windows 11
cb271c90-ce3b-481f-bee4-ecd9cfc9d893	Subin	Babbleblab	pl	1999	Windows 10
33ac73c4-dce1-4685-85ee-7b3158324731	Trippledex	Tagfeed	pl	2003	SteamOs
efef9590-a150-412c-bbe2-cb6392541bda	Viva	Miboo	pl	2011	SteamOs
085b37bd-3f67-4618-aced-3c86a7eb2829	Bitwolf	Voomm	fr	1995	Windows 11
68ca255e-09c2-4055-b455-50d275e2301e	Veribet	Voomm	fr	2006	Linux
f45d272c-226c-4737-b725-3359d2702334	Konklab	Abata	pl	2001	SteamOs
230b35c9-a12b-4c43-9e76-8ccc93b53b89	Ronstring	Yodel	en	1995	Windows 11
1185f05b-01c9-412f-a891-8b10c1e96568	Zontrax	Feednation	pl	2007	SteamOs
d9cc25b8-bd84-4833-8a7b-b334b0c22f47	Lotlux	Omba	ge	2008	Linux
b4a0460b-cfe6-4966-8763-e6a9de0e4473	Span	Youfeed	ge	1991	Windows 11
71806139-4eb5-43d1-93f2-56087ff6157d	Kanlam	Kaymbo	pl	1997	SteamOs
46c6463a-bf07-4413-87ee-5ceac88eb257	Konklab	Agimba	en	2007	Linux
05b4e9d5-09b1-4116-8fc5-9b697d0c6add	Ronstring	Tagcat	en	2008	Linux
89796987-1e82-4a29-bd48-757f8e24664d	Subin	Digitube	pl	2008	Windows 11
0c28a1f2-d64c-4a39-867f-630ccbab5058	Wrapsafe	Skaboo	en	2005	Linux
d636ed56-4635-429f-b219-d107fec79809	Holdlamis	Yakidoo	en	2001	Linux
dfaaf187-c607-4355-8578-d70a2da0b0e2	Span	Rhyzio	en	2000	Windows 10
3ae6df32-6202-4756-8b32-7f78c6832964	Zathin	Meembee	en	1998	Linux
e003721f-3b73-47b0-bd41-bf5b47474fb1	Pannier	Youfeed	pl	2000	Linux
2bbbfc13-41e7-4f27-88b9-57b05a8e4012	Home Ing	JumpXS	en	1992	Windows 11
5f6dc351-c41c-4dfe-b74d-f6e7f186fff3	Vagram	Skimia	pl	2003	Windows 11
75523893-b476-4f46-8b4c-9640e8c5ec2f	Transcof	Jabbertype	fr	2000	Windows 10
2e7e3130-0947-4ef3-816c-c7aec8df890f	Ronstring	Avamba	en	2011	Linux
cbc4c822-df3b-4b16-ba71-0a5569f5204c	Opela	Gabvine	en	2009	Windows 10
7cb4bb44-4c84-439e-b4ea-e8b6aa019048	Konklux	Reallinks	ge	2010	Windows 10
d8fb8926-bfc6-46e7-8649-a641ec7ba8bc	Regrant	Feedbug	pl	2004	SteamOs
27a0825b-302b-4bd1-806c-af594efd5b9e	Namfix	Kwimbee	ge	2000	Windows 10
a734ee73-27c4-40dd-ba6c-e5db868af4de	Toughjoyfax	Dynabox	pl	2006	Linux
87f67105-f174-46bc-a671-9efc2905d308	Cardguard	Jayo	fr	1997	Windows 10
cfc5e63c-1fcb-4c4e-952f-752c9711c26e	Fintone	Eadel	fr	1987	SteamOs
0f96898e-f9df-4af7-a99e-bc83c3175e30	Fixflex	JumpXS	fr	2011	Windows 10
c2f7208e-e160-4b51-a52a-a0f04967a0a5	Hatity	Riffwire	fr	2002	SteamOs
e24614eb-8f55-4b19-b043-cd2be370c8c7	Asoka	Dabshots	en	2002	Linux
12669fb5-95f6-4327-8e3c-03bae04bc2da	Bigtax	Dablist	pl	1996	Linux
30c5d642-143e-4558-9c97-44979e5fa7e0	Viva	Voonte	en	2011	Windows 10
51ab7c60-5f6a-4484-9ceb-b4d1f8b30e9e	Voyatouch	Meedoo	fr	2011	Linux
5268e931-6487-4511-9e76-70c3a6bf93e1	Sonair	Edgeify	pl	1997	Windows 11
1e8890d7-4e9b-4512-9945-45ce3643c75e	Konklux	Browsecat	ge	1984	Linux
9e737efa-1239-4ce5-a712-d7039eac2a6e	Tempsoft	Riffwire	ge	1994	Windows 10
abd15485-f078-44ae-9ea9-f7bcb23ed9f1	Duobam	Oyonder	fr	2011	SteamOs
0fff6f74-9330-4fde-9ab2-e97847a2f186	Bamity	Youtags	fr	1997	Linux
143cbc74-945a-48c9-9d6d-7d28acc72b15	Greenlam	Skalith	en	1997	Windows 10
61aaf862-10ff-45b6-a163-44481244193f	Tin	Youspan	pl	2005	Windows 10
005c6009-7530-4c82-b4ec-a8e2ca251732	Span	Quamba	ge	2009	SteamOs
e17ebf29-58a8-4b78-b167-1aaa4aafdd56	Fix San	Kazu	ge	2002	Linux
de230a1f-3451-403c-8552-6297d8ef8e7d	Quo Lux	Twitternation	fr	1993	Windows 11
eee5b102-be02-4a99-a579-ee3cb51339bd	Job	Tagopia	pl	2006	SteamOs
2d364d01-a3f6-4156-9e25-5962dbe593a3	New	Studio	pl	2002	Windows21
\.


--
-- Data for Name: game_instance; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.game_instance (share_id, archetype_id) FROM stdin;
649539c3-6c06-42cd-b2cb-099f5fa3581b	9e4858ce-70e3-4a35-9d4a-ca67ed0c8d24
9f7e5bfc-afc8-469b-9e1d-36511ec47bf2	35932c93-b4ed-49ed-807a-d532fe4fcaf9
0ae94b84-f390-4195-82c9-44e558a76099	cff3df96-0530-4570-b435-d59d5b90d289
cc827187-e665-459e-bd53-38cab8be5843	cb271c90-ce3b-481f-bee4-ecd9cfc9d893
aec3cb1f-f48d-4f5b-8c04-f885bcacff4a	33ac73c4-dce1-4685-85ee-7b3158324731
28279bd7-815d-42c2-a7a6-d999f19f415d	efef9590-a150-412c-bbe2-cb6392541bda
7f3fdc55-357c-495f-8f21-ea117815d481	085b37bd-3f67-4618-aced-3c86a7eb2829
b8018acc-9aef-4b73-9a4e-e01d84d9f318	68ca255e-09c2-4055-b455-50d275e2301e
9ff3816d-03e2-49cd-98e0-e558f15df6d6	f45d272c-226c-4737-b725-3359d2702334
d21abf58-b53c-4f6b-a0e7-96183b854457	230b35c9-a12b-4c43-9e76-8ccc93b53b89
3519f342-fe6b-405d-a513-86b37c884450	1185f05b-01c9-412f-a891-8b10c1e96568
1989b0bc-4378-4a6e-8535-e81173133f93	d9cc25b8-bd84-4833-8a7b-b334b0c22f47
48ad2dc0-ec6e-4a32-b418-6f750576e8a8	b4a0460b-cfe6-4966-8763-e6a9de0e4473
baa71d99-dee1-4481-9c5a-53d8c6d037cc	9e4858ce-70e3-4a35-9d4a-ca67ed0c8d24
052caf5c-4979-41e6-aa45-32fb141b8707	9e4858ce-70e3-4a35-9d4a-ca67ed0c8d24
f31eef57-5cf3-4153-b9ff-0a044d67718d	9e4858ce-70e3-4a35-9d4a-ca67ed0c8d24
ab0b02f5-f5f5-4b66-a53f-33331f5102ef	9e4858ce-70e3-4a35-9d4a-ca67ed0c8d24
3da98c5f-43b8-4b47-af3d-f27aef95f415	9e4858ce-70e3-4a35-9d4a-ca67ed0c8d24
ec339108-81b4-42b8-b938-7984bfdf60e4	9e4858ce-70e3-4a35-9d4a-ca67ed0c8d24
eeaf8b8e-921d-4f53-8a5a-8ef0da867ceb	9e4858ce-70e3-4a35-9d4a-ca67ed0c8d24
f3d5d56c-029a-4929-a1bd-9fd484908ebf	9e4858ce-70e3-4a35-9d4a-ca67ed0c8d24
1b1f7ab0-7f0c-4c2c-8296-10fc81034234	9e4858ce-70e3-4a35-9d4a-ca67ed0c8d24
\.


--
-- Data for Name: music_archetype; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.music_archetype (id, length_epoch, format, album_name, release_year) FROM stdin;
a50e474a-ad72-4163-94f3-25f5262a96c5	7163	.flac	Cardify	2010
dec1a206-df35-4489-b7ed-020f9ef8af41	241	.wav	Asoka	2001
e94a0b00-113a-4b65-a794-e671a573c22c	3120	.flac	Regrant	2001
56aa3d9e-7608-4b16-ab55-a51833b5c6ef	296	.wav	Bitchip	2001
453952c3-eb90-4a5b-b67e-ce176c90a66c	4407	.wav	Latlux	1992
9d8e5159-c392-43c6-9364-45d481e832d3	9226	.mp3	Solarbreeze	1992
d4596eb7-27cd-4e80-8b03-274e0b363caa	7936	.flac	Sub-Ex	1998
983ccbbf-ee64-4736-94b1-18730e65de98	7810	.wav	Matsoft	1986
78228fca-9abe-4a5e-b592-2b69930e0337	3832	.flac	Stim	1995
676b66be-0a6c-4eac-93da-677a723b6768	958	.wav	Lotstring	1985
c5d93082-4b2a-43fc-a1f7-0283eb6ee208	6648	.wav	It	2001
95816af8-6c82-45fe-ba66-7ad175fd4580	7300	.mp3	Flexidy	1977
b9e9719b-2ff3-4787-8989-32c1889d7095	550	.flac	Wrapsafe	2001
f87c6dfe-2c2a-4461-829e-a76f00d5852f	5678	.flac	Job	2003
6bcd4a96-461d-4f3e-b747-5f5b56a91a0b	3504	.wav	Greenlam	2012
a5145a34-5b19-491a-b953-a6ea7eda3a9e	2319	.flac	Viva	2005
52e4944d-d88f-4c7a-aed4-cfdfcf80b12e	2022	.flac	Konklab	1993
adc69aa7-3bcc-4d90-9ed9-76a05ce3d0c8	1654	.wav	Opela	2004
60c4f96e-75a5-41e6-bfd1-56f422d65377	5789	.flac	Redhold	1993
bc1fb10a-841f-4996-832a-69bbb6618b9a	9196	.mp3	Kanlam	2000
3bb34cec-5651-4056-8ede-9043b4cd12ba	1835	.wav	Gembucket	2011
f95ae077-9609-4f9f-8aba-a2682dc3c8cb	4986	.flac	Fixflex	1992
33b46d16-5ecb-4158-aa46-5ad1f56446b6	8721	.flac	Quo Lux	2009
9379be53-de75-458f-8cf7-95f3a76ca110	2325	.mp3	Pannier	1996
befd5d32-a43a-47ea-8637-bae8500ab0f0	9639	.flac	Viva	2007
1651ba87-f8eb-4c16-a7a4-e26a09f03a35	671	.flac	Job	2006
f85701f9-1a60-4574-9015-678905a19877	574	.wav	Subin	2007
28183bc5-b546-41e2-8aba-f671e57380d2	5499	.wav	Lotstring	2005
7161dbae-a946-4302-92bf-b7dabee9fb27	2669	.mp3	Voltsillam	2013
ab43751d-3323-4966-8854-950e808f8b44	6862	.flac	Tempsoft	2008
4b6cb172-dd66-452b-9870-5b50bd6d17f4	9181	.wav	Mat Lam Tam	2009
31ca2eb9-c1f0-4348-affc-bfa4e365b136	4099	.flac	Temp	2006
b3dd23e3-343e-429b-91c6-11467d434882	2260	.wav	Bamity	1995
32ae10f7-8b1e-46ed-abac-f18ddce5cbda	9482	.wav	Zathin	1998
0ca246a7-329e-4098-bde7-13a0d382447a	3642	.mp3	Voyatouch	2010
d7f9ae7d-a1e0-452d-b6ce-d896d7777f1f	5957	.flac	Y-find	1996
68f2e5b1-aec9-4fe4-aea5-71b6582fd610	8142	.flac	Voyatouch	2012
5cf7441f-bb1f-4c20-a17b-1aa24e3411a8	7705	.wav	Transcof	1989
e93da685-2fa5-440f-b334-3468e64f65fc	830	.mp3	Asoka	2002
e0292c13-bb42-4603-a388-01fb25d76b84	7017	.mp3	Stronghold	1993
95242053-5154-404e-a538-ee7134afd2b7	4935	.flac	Bytecard	2007
ca5a4dd5-94d8-40a9-bee0-99c4a612283e	8199	.wav	It	1992
54fb2734-f537-42d8-a280-7dbb59ee5fbb	415	.mp3	Domainer	2012
6f511bae-4de7-4aee-80c4-dab8f7c4aba6	4661	.wav	Solarbreeze	2011
179a20bb-ecb3-4be0-a4b5-1a97239eed9c	3036	.mp3	Rank	2006
a3539a8f-c48e-49bb-bf9f-d112fd7af141	9561	.flac	Zontrax	1984
83dfde07-d709-4898-a71f-b2cb08658378	1536	.mp3	Trippledex	2007
b0a36e94-f8fe-4dfa-9891-e4cf0911ed2f	350	.wav	Sonsing	2006
a188b67e-2ec9-4f1c-8905-63b59280d828	5461	.wav	Konklab	2011
07fdab10-8898-4ad3-9da6-1602d1a62461	760	.wav	Stim	2007
\.


--
-- Data for Name: music_instance; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.music_instance (share_id, archetype_id) FROM stdin;
5a441f82-f6b3-4412-96bc-6eac13bb4442	a50e474a-ad72-4163-94f3-25f5262a96c5
b5b468c3-d129-4715-b94a-1bc98368fe5a	dec1a206-df35-4489-b7ed-020f9ef8af41
86a74d25-4761-478c-87b4-888b9cbc0707	e94a0b00-113a-4b65-a794-e671a573c22c
72601402-45fd-4af9-a779-a5bf788c7427	56aa3d9e-7608-4b16-ab55-a51833b5c6ef
6aa55a1d-a703-4853-950b-331925635629	453952c3-eb90-4a5b-b67e-ce176c90a66c
e7217078-b339-4d3e-b469-f161c73fc081	9d8e5159-c392-43c6-9364-45d481e832d3
6b11809f-c22c-412a-87d1-ed23f3f7ba56	d4596eb7-27cd-4e80-8b03-274e0b363caa
5a3dc10f-a2e3-4363-bcad-e65723178e98	983ccbbf-ee64-4736-94b1-18730e65de98
2b4c59a1-96b7-4eee-a47d-3d69d8cf8fd9	78228fca-9abe-4a5e-b592-2b69930e0337
8831ded5-b91b-44f6-970b-f20d77c9d95b	676b66be-0a6c-4eac-93da-677a723b6768
86736cd2-f038-4b25-b2ee-0ca150d2f4b4	c5d93082-4b2a-43fc-a1f7-0283eb6ee208
354ed58b-32c5-4aa8-b002-a771bf2a85cb	95816af8-6c82-45fe-ba66-7ad175fd4580
ce73ea30-a02d-47fd-8780-7ea398f64712	b9e9719b-2ff3-4787-8989-32c1889d7095
4202c24a-f90d-43d5-aa2a-5d38327f5ee7	f87c6dfe-2c2a-4461-829e-a76f00d5852f
8e028a64-e408-444d-a608-fa2d106fd195	6bcd4a96-461d-4f3e-b747-5f5b56a91a0b
ac8225ee-d339-43ad-a225-5e62372ef759	a5145a34-5b19-491a-b953-a6ea7eda3a9e
cd66b88c-50c7-4ca8-b276-9532b0ebbca2	52e4944d-d88f-4c7a-aed4-cfdfcf80b12e
3690ea3a-a63d-41c8-807f-f223159c9f1f	adc69aa7-3bcc-4d90-9ed9-76a05ce3d0c8
43660367-7831-44f9-903e-4761f20b1a7b	60c4f96e-75a5-41e6-bfd1-56f422d65377
e2d28848-9849-4e1d-ba0a-097d7d604859	bc1fb10a-841f-4996-832a-69bbb6618b9a
075281ab-a70f-4b3f-8869-05bca711fa67	3bb34cec-5651-4056-8ede-9043b4cd12ba
76eccf00-d73b-4197-a457-727781dcee4f	f95ae077-9609-4f9f-8aba-a2682dc3c8cb
f786fddd-690f-498d-bee8-f9f6cc63be35	33b46d16-5ecb-4158-aa46-5ad1f56446b6
105ba1d4-6a52-4472-a3d9-d7f8787dcc20	9379be53-de75-458f-8cf7-95f3a76ca110
664fb721-7d28-445d-8578-1fcdb420a221	befd5d32-a43a-47ea-8637-bae8500ab0f0
4ef11c56-6d5e-4549-ac12-68bf6d4e0e3c	1651ba87-f8eb-4c16-a7a4-e26a09f03a35
7111b66b-452b-4ea3-94de-d4b9df8afc12	f85701f9-1a60-4574-9015-678905a19877
\.


--
-- Data for Name: operating_system; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.operating_system (name) FROM stdin;
Windows 10
SteamOs
Windows 11
Linux
OSX
Windows21
\.


--
-- Data for Name: resource; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.resource (id, upload_time, leeches, seeders, info_sha256, url, is_legal, size_in_bytes) FROM stdin;
3b85e730-fa0d-4f46-ab5b-9aeeb85ea27d	2024-02-02 07:11:27	29	51	\\x34373935313866363564353535373464626637633566386362303234373664653963323161353939626535613931323736393566373366663733633639616562	https://msn.com/mi/in/porttitor/pede/justo/eu/massa.jpg?quam=diam&sollicitudin=erat&vitae=fermentum&consectetuer=justo&eget=nec&rutrum=condimentum&at=neque&lorem=sapien&integer=placerat&tincidunt=ante&ante=nulla&vel=justo&ipsum=aliquam&praesent=quis&blandit=turpis&lacinia=eget&erat=elit&vestibulum=sodales&sed=scelerisque&magna=mauris&at=sit&nunc=amet&commodo=eros&placerat=suspendisse&praesent=accumsan&blandit=tortor&nam=quis&nulla=turpis&integer=sed&pede=ante&justo=vivamus&lacinia=tortor&eget=duis&tincidunt=mattis&eget=egestas&tempus=metus&vel=aenean&pede=fermentum&morbi=donec&porttitor=ut&lorem=mauris&id=eget&ligula=massa&suspendisse=tempor&ornare=convallis&consequat=nulla&lectus=neque&in=libero&est=convallis&risus=eget&auctor=eleifend&sed=luctus&tristique=ultricies&in=eu&tempus=nibh&sit=quisque&amet=id&sem=justo&fusce=sit&consequat=amet&nulla=sapien&nisl=dignissim&nunc=vestibulum&nisl=vestibulum&duis=ante&bibendum=ipsum&felis=primis&sed=in&interdum=faucibus&venenatis=orci&turpis=luctus&enim=et&blandit=ultrices	t	78838
5a441f82-f6b3-4412-96bc-6eac13bb4442	2023-12-15 10:53:10	4	72	\\x39646438316536343437353639363866613333313965356533396364616166353432636563323132623965616130626336376637363766663333663963646566	https://yellowpages.com/magna/vulputate/luctus/cum.jpg?vivamus=purus&vel=phasellus&nulla=in&eget=felis&eros=donec&elementum=semper&pellentesque=sapien&quisque=a&porta=libero&volutpat=nam&erat=dui&quisque=proin&erat=leo&eros=odio&viverra=porttitor&eget=id&congue=consequat&eget=in&semper=consequat&rutrum=ut	t	11874
b5b468c3-d129-4715-b94a-1bc98368fe5a	2023-10-29 19:14:36	86	14	\\x30343461323038383730346636616439373631313431393463616363353431653137366366313636393363333361356530333231303936656639303833393332	http://bravesites.com/congue/vivamus/metus/arcu/adipiscing.js?pretium=porta&nisl=volutpat&ut=erat&volutpat=quisque&sapien=erat&arcu=eros&sed=viverra&augue=eget&aliquam=congue&erat=eget&volutpat=semper&in=rutrum&congue=nulla&etiam=nunc&justo=purus&etiam=phasellus&pretium=in&iaculis=felis&justo=donec&in=semper&hac=sapien&habitasse=a&platea=libero&dictumst=nam&etiam=dui&faucibus=proin&cursus=leo&urna=odio&ut=porttitor&tellus=id&nulla=consequat&ut=in&erat=consequat&id=ut&mauris=nulla&vulputate=sed&elementum=accumsan&nullam=felis&varius=ut&nulla=at&facilisi=dolor&cras=quis&non=odio&velit=consequat&nec=varius&nisi=integer&vulputate=ac&nonummy=leo&maecenas=pellentesque&tincidunt=ultrices&lacus=mattis&at=odio&velit=donec&vivamus=vitae&vel=nisi&nulla=nam&eget=ultrices&eros=libero&elementum=non&pellentesque=mattis&quisque=pulvinar&porta=nulla&volutpat=pede&erat=ullamcorper&quisque=augue&erat=a&eros=suscipit&viverra=nulla&eget=elit&congue=ac&eget=nulla&semper=sed&rutrum=vel&nulla=enim&nunc=sit	f	42168
649539c3-6c06-42cd-b2cb-099f5fa3581b	2023-11-27 06:57:00	30	78	\\x65333831383735336164333337383566633034656332356463316238656437356563376161343466363337646166386230653764386263353336393863666134	https://ebay.co.uk/eget/massa/tempor/convallis/nulla.png?id=ut&sapien=volutpat&in=sapien&sapien=arcu&iaculis=sed&congue=augue&vivamus=aliquam&metus=erat&arcu=volutpat&adipiscing=in&molestie=congue&hendrerit=etiam&at=justo&vulputate=etiam&vitae=pretium&nisl=iaculis&aenean=justo&lectus=in&pellentesque=hac&eget=habitasse&nunc=platea&donec=dictumst&quis=etiam&orci=faucibus&eget=cursus&orci=urna&vehicula=ut&condimentum=tellus&curabitur=nulla&in=ut&libero=erat&ut=id&massa=mauris&volutpat=vulputate&convallis=elementum&morbi=nullam&odio=varius&odio=nulla&elementum=facilisi&eu=cras&interdum=non&eu=velit&tincidunt=nec&in=nisi&leo=vulputate&maecenas=nonummy&pulvinar=maecenas&lobortis=tincidunt&est=lacus&phasellus=at&sit=velit&amet=vivamus&erat=vel&nulla=nulla&tempus=eget	t	21812
068cde22-250b-4310-8298-2f07a2f28e58	2024-01-30 20:12:35	94	73	\\x31303630396239356665623837393233623637343333616635356539343361616534383230623439373761376666663665626437636461633533663232633630	https://tripod.com/volutpat/in/congue/etiam/justo.xml?diam=rhoncus	f	82274
8d9c11e6-678e-41f8-b4bb-5e61bf917c03	2024-08-10 12:51:42	39	6	\\x39346333343232623436633664363337623131353434643038393065613838303330626163346261653230333633323530646162346663633039363534323731	http://theglobeandmail.com/est/lacinia/nisi/venenatis.jpg?accumsan=amet&felis=turpis&ut=elementum&at=ligula&dolor=vehicula&quis=consequat&odio=morbi&consequat=a&varius=ipsum&integer=integer&ac=a&leo=nibh	f	4477
4c4cd997-bc95-411a-b536-0d80bbb32276	2024-09-14 04:15:33	3	71	\\x66623161393431336362616535313061373261613833613664663537346232633266323734343863663463393532396663643162386364343331643836326631	http://loc.gov/dolor/morbi/vel/lectus/in/quam.json?ipsum=eu&integer=felis&a=fusce&nibh=posuere&in=felis&quis=sed&justo=lacus&maecenas=morbi&rhoncus=sem&aliquam=mauris&lacus=laoreet&morbi=ut&quis=rhoncus&tortor=aliquet&id=pulvinar&nulla=sed&ultrices=nisl&aliquet=nunc&maecenas=rhoncus&leo=dui&odio=vel&condimentum=sem&id=sed&luctus=sagittis&nec=nam&molestie=congue&sed=risus&justo=semper&pellentesque=porta&viverra=volutpat&pede=quam&ac=pede&diam=lobortis&cras=ligula&pellentesque=sit&volutpat=amet&dui=eleifend&maecenas=pede&tristique=libero&est=quis&et=orci&tempus=nullam&semper=molestie&est=nibh&quam=in&pharetra=lectus&magna=pellentesque&ac=at&consequat=nulla&metus=suspendisse&sapien=potenti&ut=cras&nunc=in&vestibulum=purus&ante=eu&ipsum=magna&primis=vulputate&in=luctus&faucibus=cum&orci=sociis&luctus=natoque&et=penatibus&ultrices=et&posuere=magnis&cubilia=dis&curae=parturient&mauris=montes&viverra=nascetur&diam=ridiculus&vitae=mus&quam=vivamus&suspendisse=vestibulum&potenti=sagittis&nullam=sapien&porttitor=cum&lacus=sociis&at=natoque&turpis=penatibus&donec=et&posuere=magnis&metus=dis&vitae=parturient&ipsum=montes	t	1458
2731312a-5a85-48bd-88cc-613e00777a74	2024-04-03 05:17:42	47	71	\\x61663237303562633730393938623935353039396162616235616136383434366332303763306334366637643663656138346633303131393339653330336638	http://guardian.co.uk/in/sagittis/dui.jpg?velit=mauris&donec=eget&diam=massa&neque=tempor&vestibulum=convallis&eget=nulla&vulputate=neque&ut=libero&ultrices=convallis&vel=eget&augue=eleifend&vestibulum=luctus&ante=ultricies&ipsum=eu&primis=nibh&in=quisque&faucibus=id&orci=justo&luctus=sit&et=amet&ultrices=sapien&posuere=dignissim&cubilia=vestibulum&curae=vestibulum	f	93037
9f7e5bfc-afc8-469b-9e1d-36511ec47bf2	2024-06-02 02:16:07	91	67	\\x61386333656331366463396638663130633133623738616334336363333661373737313365306566643033376166616435633362383833323061626437366136	https://cbc.ca/amet/nulla/quisque/arcu/libero/rutrum/ac.js?pulvinar=turpis&sed=integer&nisl=aliquet&nunc=massa&rhoncus=id&dui=lobortis&vel=convallis&sem=tortor&sed=risus&sagittis=dapibus&nam=augue&congue=vel&risus=accumsan&semper=tellus&porta=nisi&volutpat=eu&quam=orci	t	62847
86a74d25-4761-478c-87b4-888b9cbc0707	2024-08-05 00:18:25	10	59	\\x39393234386535633936316634633032333434393837316635633666393765356134383764383437353033666339363535336166363166656233623933363634	https://weather.com/posuere/cubilia/curae/duis/faucibus/accumsan.png?lectus=blandit&aliquam=mi&sit=in&amet=porttitor&diam=pede&in=justo&magna=eu&bibendum=massa&imperdiet=donec&nullam=dapibus&orci=duis&pede=at	f	70740
72601402-45fd-4af9-a779-a5bf788c7427	2024-03-09 13:33:27	7	30	\\x39336663373433656265633735643166333334336166313235633732376134613431346635636631653138653763653137653834313738666535313164343564	https://dell.com/non/quam/nec.aspx?pede=eleifend&venenatis=donec&non=ut&sodales=dolor&sed=morbi&tincidunt=vel&eu=lectus&felis=in&fusce=quam&posuere=fringilla&felis=rhoncus&sed=mauris&lacus=enim&morbi=leo&sem=rhoncus&mauris=sed&laoreet=vestibulum&ut=sit&rhoncus=amet&aliquet=cursus&pulvinar=id&sed=turpis&nisl=integer&nunc=aliquet&rhoncus=massa&dui=id&vel=lobortis&sem=convallis&sed=tortor&sagittis=risus&nam=dapibus&congue=augue&risus=vel&semper=accumsan&porta=tellus&volutpat=nisi&quam=eu&pede=orci&lobortis=mauris&ligula=lacinia&sit=sapien&amet=quis&eleifend=libero&pede=nullam&libero=sit&quis=amet	t	72078
6aa55a1d-a703-4853-950b-331925635629	2024-04-03 11:58:56	62	95	\\x34353466636563646532333030393431393634323730353431616433366564663863643966623565393465366336656130336566383639663034653362343338	https://cloudflare.com/condimentum/curabitur/in.png?vel=semper&nulla=est&eget=quam&eros=pharetra&elementum=magna&pellentesque=ac&quisque=consequat&porta=metus&volutpat=sapien&erat=ut&quisque=nunc&erat=vestibulum&eros=ante&viverra=ipsum&eget=primis&congue=in&eget=faucibus&semper=orci&rutrum=luctus&nulla=et&nunc=ultrices&purus=posuere&phasellus=cubilia&in=curae&felis=mauris&donec=viverra	t	43927
fac7e88a-d9ca-474e-a165-a490faa20515	2024-09-20 08:32:48	86	23	\\x39343438656331303733346464336162643263363866613838393337653166323361303339313165396531356239303961383931663265613163386363653039	https://sciencedaily.com/sollicitudin/vitae.js?curabitur=nulla&gravida=mollis&nisi=molestie&at=lorem&nibh=quisque&in=ut&hac=erat&habitasse=curabitur&platea=gravida&dictumst=nisi&aliquam=at&augue=nibh&quam=in&sollicitudin=hac&vitae=habitasse&consectetuer=platea&eget=dictumst&rutrum=aliquam&at=augue&lorem=quam&integer=sollicitudin&tincidunt=vitae&ante=consectetuer&vel=eget&ipsum=rutrum&praesent=at&blandit=lorem&lacinia=integer&erat=tincidunt&vestibulum=ante&sed=vel&magna=ipsum&at=praesent&nunc=blandit&commodo=lacinia&placerat=erat	t	34528
e7217078-b339-4d3e-b469-f161c73fc081	2024-10-24 14:01:55	89	100	\\x34366631663265663837353565646265326334663737373239623535633339346664643936663339386237613731336533633266636235386539396233363366	https://creativecommons.org/orci/luctus/et/ultrices/posuere/cubilia/curae.xml?ridiculus=eget&mus=rutrum&etiam=at&vel=lorem&augue=integer&vestibulum=tincidunt&rutrum=ante&rutrum=vel&neque=ipsum&aenean=praesent&auctor=blandit&gravida=lacinia&sem=erat&praesent=vestibulum&id=sed	f	69382
c7a5009c-2ae5-44c5-afb5-bf64c46fe26c	2024-07-26 23:22:02	69	5	\\x65333432303562643536623235353663363166323338616634376338326238633230633639656634313565356431336334666135343166323662333932393032	http://google.pl/magna/bibendum/imperdiet/nullam.jpg?in=nisi&eleifend=eu&quam=orci&a=mauris&odio=lacinia&in=sapien&hac=quis&habitasse=libero&platea=nullam&dictumst=sit&maecenas=amet&ut=turpis&massa=elementum&quis=ligula&augue=vehicula&luctus=consequat&tincidunt=morbi&nulla=a&mollis=ipsum&molestie=integer&lorem=a&quisque=nibh&ut=in&erat=quis&curabitur=justo	f	4899
258dc54d-1b37-4100-84ce-b73b82a9a5f8	2024-07-27 08:36:20	57	75	\\x35343937636165396138653636386235323032353633346336616233343934356663633934333938303730376266396535663962643837643338396565393838	http://ucoz.com/diam/cras/pellentesque/volutpat/dui/maecenas.jsp?sapien=eu&cum=est&sociis=congue&natoque=elementum&penatibus=in&et=hac&magnis=habitasse&dis=platea&parturient=dictumst&montes=morbi&nascetur=vestibulum&ridiculus=velit&mus=id&etiam=pretium&vel=iaculis&augue=diam&vestibulum=erat&rutrum=fermentum&rutrum=justo&neque=nec&aenean=condimentum&auctor=neque&gravida=sapien&sem=placerat&praesent=ante&id=nulla&massa=justo&id=aliquam&nisl=quis&venenatis=turpis&lacinia=eget&aenean=elit&sit=sodales&amet=scelerisque&justo=mauris&morbi=sit&ut=amet&odio=eros&cras=suspendisse&mi=accumsan&pede=tortor&malesuada=quis&in=turpis&imperdiet=sed&et=ante&commodo=vivamus&vulputate=tortor&justo=duis&in=mattis	t	74161
b87992d0-07e8-4722-a46c-0c485531769a	2024-07-21 21:06:39	64	45	\\x65333637373831386565303530366533666430376436383733643031616430383338323661353163356632633963663035623838303061643431663435326464	https://twitter.com/a/odio/in/hac/habitasse.png?cras=libero&non=nam&velit=dui&nec=proin&nisi=leo&vulputate=odio&nonummy=porttitor&maecenas=id&tincidunt=consequat&lacus=in&at=consequat&velit=ut&vivamus=nulla&vel=sed&nulla=accumsan&eget=felis&eros=ut&elementum=at&pellentesque=dolor&quisque=quis&porta=odio&volutpat=consequat&erat=varius&quisque=integer&erat=ac	f	71024
de2adefd-7799-4a41-b0b5-443c11fa046e	2024-03-06 01:05:10	74	67	\\x64396434376332633337333764386339613130616332626432346666623862306338656365643732386262613632373765623134373239333635393362376338	https://webeden.co.uk/consectetuer/eget/rutrum/at/lorem/integer/tincidunt.jpg?nibh=donec&in=odio&quis=justo&justo=sollicitudin&maecenas=ut&rhoncus=suscipit&aliquam=a&lacus=feugiat&morbi=et&quis=eros&tortor=vestibulum&id=ac&nulla=est&ultrices=lacinia&aliquet=nisi&maecenas=venenatis&leo=tristique&odio=fusce&condimentum=congue&id=diam&luctus=id&nec=ornare&molestie=imperdiet&sed=sapien&justo=urna&pellentesque=pretium&viverra=nisl&pede=ut&ac=volutpat&diam=sapien&cras=arcu&pellentesque=sed&volutpat=augue&dui=aliquam&maecenas=erat&tristique=volutpat&est=in&et=congue&tempus=etiam&semper=justo&est=etiam&quam=pretium&pharetra=iaculis&magna=justo&ac=in&consequat=hac&metus=habitasse&sapien=platea&ut=dictumst&nunc=etiam&vestibulum=faucibus&ante=cursus&ipsum=urna&primis=ut&in=tellus	t	96949
0ae94b84-f390-4195-82c9-44e558a76099	2024-04-11 12:07:53	88	82	\\x66333835323130663761333065363363656166616261376134653536373266313532373461333562353566306637646335616234373738356536366536303036	http://cocolog-nifty.com/hac/habitasse/platea.png?cras=vestibulum&pellentesque=ante&volutpat=ipsum&dui=primis&maecenas=in&tristique=faucibus&est=orci&et=luctus&tempus=et&semper=ultrices&est=posuere&quam=cubilia&pharetra=curae&magna=mauris&ac=viverra&consequat=diam&metus=vitae&sapien=quam&ut=suspendisse&nunc=potenti&vestibulum=nullam&ante=porttitor&ipsum=lacus&primis=at&in=turpis&faucibus=donec&orci=posuere&luctus=metus&et=vitae&ultrices=ipsum&posuere=aliquam&cubilia=non&curae=mauris&mauris=morbi&viverra=non&diam=lectus&vitae=aliquam&quam=sit&suspendisse=amet&potenti=diam&nullam=in&porttitor=magna&lacus=bibendum&at=imperdiet&turpis=nullam&donec=orci&posuere=pede&metus=venenatis&vitae=non&ipsum=sodales&aliquam=sed&non=tincidunt&mauris=eu&morbi=felis&non=fusce&lectus=posuere&aliquam=felis&sit=sed&amet=lacus&diam=morbi&in=sem&magna=mauris&bibendum=laoreet&imperdiet=ut&nullam=rhoncus&orci=aliquet	f	46865
6b11809f-c22c-412a-87d1-ed23f3f7ba56	2024-06-16 14:22:20	89	18	\\x64366230356263653061393236666232303830643030616539393664636437363739316436373430383035396234373932626539343930613261613830633762	http://discovery.com/mattis/odio.jsp?pulvinar=faucibus&lobortis=accumsan&est=odio&phasellus=curabitur&sit=convallis&amet=duis&erat=consequat&nulla=dui&tempus=nec&vivamus=nisi&in=volutpat&felis=eleifend&eu=donec&sapien=ut&cursus=dolor&vestibulum=morbi&proin=vel&eu=lectus&mi=in&nulla=quam&ac=fringilla&enim=rhoncus&in=mauris&tempor=enim&turpis=leo&nec=rhoncus&euismod=sed&scelerisque=vestibulum&quam=sit&turpis=amet&adipiscing=cursus&lorem=id&vitae=turpis&mattis=integer&nibh=aliquet&ligula=massa&nec=id&sem=lobortis&duis=convallis	t	14250
9f527479-34d3-423c-875b-a20c88bab7f1	2024-04-06 05:36:49	18	81	\\x38656262313964396362316434356635373864336439623434386361353534663563343733616438376631616536356338356161633339363036373563363439	http://example.com/quam/sapien/varius/ut/blandit/non/interdum.html?orci=et&mauris=ultrices&lacinia=posuere&sapien=cubilia&quis=curae&libero=mauris&nullam=viverra&sit=diam&amet=vitae&turpis=quam&elementum=suspendisse&ligula=potenti&vehicula=nullam&consequat=porttitor&morbi=lacus&a=at&ipsum=turpis&integer=donec&a=posuere&nibh=metus&in=vitae&quis=ipsum&justo=aliquam&maecenas=non&rhoncus=mauris&aliquam=morbi&lacus=non&morbi=lectus&quis=aliquam&tortor=sit&id=amet&nulla=diam&ultrices=in&aliquet=magna&maecenas=bibendum&leo=imperdiet&odio=nullam&condimentum=orci&id=pede&luctus=venenatis&nec=non&molestie=sodales&sed=sed&justo=tincidunt&pellentesque=eu&viverra=felis&pede=fusce&ac=posuere&diam=felis&cras=sed&pellentesque=lacus&volutpat=morbi&dui=sem&maecenas=mauris&tristique=laoreet&est=ut&et=rhoncus&tempus=aliquet&semper=pulvinar&est=sed&quam=nisl&pharetra=nunc&magna=rhoncus&ac=dui&consequat=vel&metus=sem&sapien=sed&ut=sagittis&nunc=nam&vestibulum=congue&ante=risus&ipsum=semper&primis=porta&in=volutpat&faucibus=quam&orci=pede&luctus=lobortis&et=ligula&ultrices=sit&posuere=amet&cubilia=eleifend&curae=pede&mauris=libero&viverra=quis&diam=orci&vitae=nullam&quam=molestie&suspendisse=nibh&potenti=in&nullam=lectus&porttitor=pellentesque&lacus=at&at=nulla&turpis=suspendisse&donec=potenti	t	29620
5a3dc10f-a2e3-4363-bcad-e65723178e98	2024-01-14 23:15:04	17	55	\\x30666566346537343861636137613561303033626461666465376637333231306534333037316239313964633066633564636564323133636239353338383264	http://utexas.edu/vitae/mattis/nibh/ligula/nec/sem.xml?vel=sapien&sem=cursus&sed=vestibulum&sagittis=proin&nam=eu&congue=mi&risus=nulla&semper=ac&porta=enim&volutpat=in&quam=tempor&pede=turpis&lobortis=nec&ligula=euismod&sit=scelerisque&amet=quam&eleifend=turpis&pede=adipiscing&libero=lorem&quis=vitae	t	30733
cc827187-e665-459e-bd53-38cab8be5843	2023-12-16 06:03:10	68	42	\\x35646238303361383639376139343437376164376562623035353234363133313233666464316236386230326661306561393338653565623735393035373830	https://e-recht24.de/faucibus/orci/luctus/et/ultrices.html?donec=elementum&vitae=nullam&nisi=varius&nam=nulla&ultrices=facilisi&libero=cras&non=non&mattis=velit&pulvinar=nec&nulla=nisi&pede=vulputate&ullamcorper=nonummy&augue=maecenas&a=tincidunt&suscipit=lacus&nulla=at&elit=velit&ac=vivamus&nulla=vel&sed=nulla&vel=eget&enim=eros&sit=elementum&amet=pellentesque&nunc=quisque&viverra=porta&dapibus=volutpat&nulla=erat	f	68699
2b4c59a1-96b7-4eee-a47d-3d69d8cf8fd9	2024-08-27 03:21:56	44	19	\\x63626130653833393630376262623030613332636438323061303666353731366333653964633738656638656437353231613462633434323531343030656466	http://craigslist.org/felis/donec/semper/sapien/a/libero/nam.json?magna=at&bibendum=dolor&imperdiet=quis&nullam=odio&orci=consequat&pede=varius&venenatis=integer&non=ac&sodales=leo&sed=pellentesque&tincidunt=ultrices&eu=mattis&felis=odio&fusce=donec&posuere=vitae&felis=nisi&sed=nam&lacus=ultrices&morbi=libero&sem=non&mauris=mattis&laoreet=pulvinar&ut=nulla&rhoncus=pede&aliquet=ullamcorper&pulvinar=augue&sed=a&nisl=suscipit&nunc=nulla&rhoncus=elit&dui=ac&vel=nulla&sem=sed&sed=vel&sagittis=enim&nam=sit&congue=amet&risus=nunc&semper=viverra&porta=dapibus&volutpat=nulla&quam=suscipit&pede=ligula&lobortis=in&ligula=lacus&sit=curabitur&amet=at&eleifend=ipsum&pede=ac&libero=tellus&quis=semper&orci=interdum&nullam=mauris&molestie=ullamcorper&nibh=purus&in=sit&lectus=amet&pellentesque=nulla&at=quisque&nulla=arcu&suspendisse=libero&potenti=rutrum&cras=ac&in=lobortis&purus=vel&eu=dapibus&magna=at&vulputate=diam&luctus=nam&cum=tristique&sociis=tortor	t	47880
f5c6f0f2-36ba-4217-8b47-07e79ccc357a	2024-07-06 16:03:07	71	12	\\x39666333633335306230633735343762303335363034353033653236383035656234303339646262626139333133386365396462313964376665663864356130	http://1688.com/eu/sapien/cursus/vestibulum/proin/eu/mi.png?phasellus=aenean&sit=fermentum&amet=donec&erat=ut&nulla=mauris&tempus=eget&vivamus=massa&in=tempor&felis=convallis&eu=nulla&sapien=neque&cursus=libero&vestibulum=convallis&proin=eget&eu=eleifend&mi=luctus&nulla=ultricies&ac=eu&enim=nibh&in=quisque&tempor=id&turpis=justo&nec=sit&euismod=amet&scelerisque=sapien&quam=dignissim&turpis=vestibulum&adipiscing=vestibulum&lorem=ante&vitae=ipsum&mattis=primis&nibh=in&ligula=faucibus&nec=orci&sem=luctus&duis=et&aliquam=ultrices&convallis=posuere&nunc=cubilia&proin=curae&at=nulla&turpis=dapibus&a=dolor&pede=vel&posuere=est&nonummy=donec&integer=odio&non=justo&velit=sollicitudin&donec=ut&diam=suscipit&neque=a&vestibulum=feugiat&eget=et	f	94153
22fb047a-a258-4976-9d59-26c0e5e3432a	2024-08-14 10:56:52	31	29	\\x61363661643464373837386563343033323065623662393962633832656231343264383862333338376634613437343637353165303264613536613036323439	http://smh.com.au/erat/nulla.jpg?vestibulum=nam&ante=congue&ipsum=risus&primis=semper&in=porta&faucibus=volutpat&orci=quam&luctus=pede&et=lobortis&ultrices=ligula&posuere=sit&cubilia=amet&curae=eleifend&duis=pede&faucibus=libero&accumsan=quis&odio=orci&curabitur=nullam&convallis=molestie&duis=nibh&consequat=in&dui=lectus&nec=pellentesque&nisi=at&volutpat=nulla&eleifend=suspendisse&donec=potenti&ut=cras&dolor=in&morbi=purus&vel=eu&lectus=magna&in=vulputate&quam=luctus&fringilla=cum&rhoncus=sociis&mauris=natoque&enim=penatibus&leo=et&rhoncus=magnis&sed=dis&vestibulum=parturient&sit=montes&amet=nascetur	f	14656
cb7b5a74-07c7-4102-8c1f-01578e5bd65e	2023-12-15 13:35:02	18	61	\\x61353531326133633564313837336635326439353562303665353965656232626366306431363264363339393462643166393639373034376435653038373232	http://mapquest.com/neque/libero/convallis.xml?nulla=eleifend&ac=quam&enim=a&in=odio&tempor=in&turpis=hac&nec=habitasse&euismod=platea&scelerisque=dictumst&quam=maecenas&turpis=ut&adipiscing=massa&lorem=quis&vitae=augue&mattis=luctus&nibh=tincidunt&ligula=nulla&nec=mollis&sem=molestie&duis=lorem&aliquam=quisque&convallis=ut&nunc=erat&proin=curabitur&at=gravida&turpis=nisi&a=at&pede=nibh&posuere=in&nonummy=hac&integer=habitasse&non=platea&velit=dictumst&donec=aliquam&diam=augue&neque=quam&vestibulum=sollicitudin&eget=vitae&vulputate=consectetuer&ut=eget&ultrices=rutrum&vel=at&augue=lorem&vestibulum=integer&ante=tincidunt&ipsum=ante&primis=vel&in=ipsum&faucibus=praesent&orci=blandit&luctus=lacinia&et=erat&ultrices=vestibulum&posuere=sed&cubilia=magna&curae=at&donec=nunc&pharetra=commodo&magna=placerat&vestibulum=praesent&aliquet=blandit&ultrices=nam&erat=nulla&tortor=integer&sollicitudin=pede&mi=justo&sit=lacinia&amet=eget&lobortis=tincidunt&sapien=eget&sapien=tempus&non=vel&mi=pede&integer=morbi&ac=porttitor	t	18018
abed90de-e6e3-41bb-8fec-d87ae1f22c7b	2023-12-23 02:37:14	94	93	\\x36353438386133366638386565663136393031353135333536353534396338343165643561663763616336653261653161323936613033316333633539613137	http://people.com.cn/ridiculus/mus.html?in=porttitor&blandit=id&ultrices=consequat&enim=in&lorem=consequat&ipsum=ut&dolor=nulla&sit=sed&amet=accumsan&consectetuer=felis&adipiscing=ut&elit=at&proin=dolor&interdum=quis&mauris=odio&non=consequat&ligula=varius&pellentesque=integer&ultrices=ac&phasellus=leo&id=pellentesque&sapien=ultrices&in=mattis&sapien=odio&iaculis=donec&congue=vitae&vivamus=nisi&metus=nam&arcu=ultrices&adipiscing=libero&molestie=non&hendrerit=mattis&at=pulvinar&vulputate=nulla&vitae=pede&nisl=ullamcorper&aenean=augue&lectus=a&pellentesque=suscipit&eget=nulla&nunc=elit&donec=ac&quis=nulla&orci=sed&eget=vel&orci=enim&vehicula=sit&condimentum=amet&curabitur=nunc&in=viverra&libero=dapibus&ut=nulla&massa=suscipit&volutpat=ligula&convallis=in&morbi=lacus	f	93473
16866ac4-7745-4e27-a72c-70c9031e58cb	2024-01-20 11:57:28	64	59	\\x33643133376566616236306432326362613838663933623964643166306337306362373931383532663439303363316336353832356564656434633435373464	https://reuters.com/luctus/nec/molestie/sed/justo/pellentesque/viverra.jsp?duis=sit&mattis=amet&egestas=turpis&metus=elementum&aenean=ligula&fermentum=vehicula&donec=consequat&ut=morbi&mauris=a&eget=ipsum&massa=integer&tempor=a&convallis=nibh&nulla=in&neque=quis&libero=justo&convallis=maecenas&eget=rhoncus&eleifend=aliquam&luctus=lacus&ultricies=morbi&eu=quis&nibh=tortor&quisque=id&id=nulla&justo=ultrices&sit=aliquet&amet=maecenas&sapien=leo&dignissim=odio&vestibulum=condimentum&vestibulum=id&ante=luctus&ipsum=nec&primis=molestie&in=sed&faucibus=justo&orci=pellentesque&luctus=viverra&et=pede&ultrices=ac&posuere=diam&cubilia=cras&curae=pellentesque&nulla=volutpat&dapibus=dui&dolor=maecenas&vel=tristique&est=est&donec=et&odio=tempus&justo=semper&sollicitudin=est&ut=quam&suscipit=pharetra&a=magna&feugiat=ac&et=consequat&eros=metus&vestibulum=sapien&ac=ut&est=nunc&lacinia=vestibulum&nisi=ante&venenatis=ipsum&tristique=primis&fusce=in&congue=faucibus&diam=orci&id=luctus&ornare=et&imperdiet=ultrices&sapien=posuere&urna=cubilia&pretium=curae&nisl=mauris&ut=viverra&volutpat=diam&sapien=vitae&arcu=quam&sed=suspendisse&augue=potenti	f	19720
8831ded5-b91b-44f6-970b-f20d77c9d95b	2024-10-18 23:35:38	10	75	\\x33343165623239653437623637653531626562633934313463373165343139396436623562636132623830373965336133623831336264646461633465343065	http://patch.com/integer/a/nibh.aspx?justo=morbi&in=porttitor&hac=lorem&habitasse=id&platea=ligula&dictumst=suspendisse&etiam=ornare&faucibus=consequat&cursus=lectus&urna=in&ut=est&tellus=risus&nulla=auctor&ut=sed&erat=tristique&id=in&mauris=tempus&vulputate=sit&elementum=amet&nullam=sem&varius=fusce&nulla=consequat&facilisi=nulla&cras=nisl&non=nunc&velit=nisl&nec=duis&nisi=bibendum&vulputate=felis&nonummy=sed&maecenas=interdum&tincidunt=venenatis&lacus=turpis&at=enim&velit=blandit&vivamus=mi&vel=in&nulla=porttitor&eget=pede&eros=justo&elementum=eu&pellentesque=massa&quisque=donec&porta=dapibus&volutpat=duis&erat=at&quisque=velit&erat=eu&eros=est&viverra=congue&eget=elementum&congue=in&eget=hac&semper=habitasse&rutrum=platea&nulla=dictumst&nunc=morbi&purus=vestibulum&phasellus=velit&in=id&felis=pretium&donec=iaculis&semper=diam&sapien=erat&a=fermentum&libero=justo&nam=nec&dui=condimentum&proin=neque&leo=sapien&odio=placerat&porttitor=ante&id=nulla&consequat=justo&in=aliquam&consequat=quis&ut=turpis&nulla=eget&sed=elit&accumsan=sodales&felis=scelerisque&ut=mauris&at=sit&dolor=amet&quis=eros&odio=suspendisse&consequat=accumsan&varius=tortor&integer=quis&ac=turpis&leo=sed	t	76194
7f3fdc55-357c-495f-8f21-ea117815d481	2024-05-11 06:12:51	36	63	\\x35666463316365396161333739363261333833316565633162626133653661653237643364613634633161383739313637656237636137373130663964623738	https://chronoengine.com/ut/ultrices/vel/augue/vestibulum/ante.js?vestibulum=eget&proin=congue&eu=eget&mi=semper&nulla=rutrum&ac=nulla&enim=nunc&in=purus&tempor=phasellus&turpis=in&nec=felis&euismod=donec&scelerisque=semper&quam=sapien&turpis=a&adipiscing=libero&lorem=nam&vitae=dui&mattis=proin&nibh=leo&ligula=odio&nec=porttitor&sem=id&duis=consequat&aliquam=in&convallis=consequat&nunc=ut&proin=nulla&at=sed&turpis=accumsan&a=felis&pede=ut&posuere=at&nonummy=dolor&integer=quis&non=odio&velit=consequat&donec=varius&diam=integer&neque=ac&vestibulum=leo	f	4846
aec3cb1f-f48d-4f5b-8c04-f885bcacff4a	2024-08-09 14:48:52	70	29	\\x37623361336430656363663238363538346239633139343130373263656431383934366662356163393037636565346561343338356566666134633232616161	https://elpais.com/porta/volutpat.aspx?sit=ipsum&amet=primis&justo=in&morbi=faucibus&ut=orci&odio=luctus&cras=et&mi=ultrices&pede=posuere&malesuada=cubilia&in=curae&imperdiet=donec&et=pharetra&commodo=magna&vulputate=vestibulum&justo=aliquet&in=ultrices&blandit=erat&ultrices=tortor&enim=sollicitudin&lorem=mi&ipsum=sit&dolor=amet&sit=lobortis&amet=sapien&consectetuer=sapien&adipiscing=non&elit=mi&proin=integer&interdum=ac&mauris=neque&non=duis&ligula=bibendum&pellentesque=morbi&ultrices=non&phasellus=quam&id=nec&sapien=dui&in=luctus&sapien=rutrum&iaculis=nulla&congue=tellus&vivamus=in&metus=sagittis&arcu=dui&adipiscing=vel&molestie=nisl&hendrerit=duis&at=ac&vulputate=nibh&vitae=fusce&nisl=lacus&aenean=purus&lectus=aliquet&pellentesque=at&eget=feugiat&nunc=non&donec=pretium&quis=quis&orci=lectus&eget=suspendisse&orci=potenti&vehicula=in&condimentum=eleifend&curabitur=quam&in=a&libero=odio&ut=in&massa=hac&volutpat=habitasse&convallis=platea&morbi=dictumst&odio=maecenas&odio=ut&elementum=massa&eu=quis&interdum=augue&eu=luctus&tincidunt=tincidunt&in=nulla&leo=mollis&maecenas=molestie&pulvinar=lorem&lobortis=quisque&est=ut&phasellus=erat&sit=curabitur&amet=gravida&erat=nisi&nulla=at&tempus=nibh&vivamus=in	f	80161
86736cd2-f038-4b25-b2ee-0ca150d2f4b4	2023-11-15 07:34:49	43	66	\\x39376366303663353233396362343262333663373237326438666538376364333639393036383033353936373766333932636536643131313665316631613430	http://mozilla.org/ut.aspx?vivamus=purus&metus=phasellus&arcu=in&adipiscing=felis&molestie=donec&hendrerit=semper&at=sapien&vulputate=a&vitae=libero&nisl=nam&aenean=dui&lectus=proin&pellentesque=leo&eget=odio&nunc=porttitor&donec=id&quis=consequat&orci=in&eget=consequat&orci=ut&vehicula=nulla&condimentum=sed&curabitur=accumsan&in=felis&libero=ut&ut=at&massa=dolor&volutpat=quis&convallis=odio&morbi=consequat&odio=varius&odio=integer&elementum=ac&eu=leo&interdum=pellentesque&eu=ultrices&tincidunt=mattis&in=odio&leo=donec&maecenas=vitae&pulvinar=nisi&lobortis=nam&est=ultrices&phasellus=libero&sit=non&amet=mattis&erat=pulvinar&nulla=nulla&tempus=pede&vivamus=ullamcorper&in=augue&felis=a&eu=suscipit&sapien=nulla&cursus=elit	f	59937
19678a34-e91d-4103-b576-9474d67ea982	2024-08-25 15:07:56	69	77	\\x65313230366631613436333261643163383865343766326561666335333730336163363635336664313236313233326665633666633530613865326336313663	http://ifeng.com/tristique/in/tempus/sit/amet/sem.xml?nullam=facilisi&orci=cras&pede=non&venenatis=velit&non=nec&sodales=nisi&sed=vulputate&tincidunt=nonummy&eu=maecenas&felis=tincidunt&fusce=lacus&posuere=at&felis=velit&sed=vivamus&lacus=vel&morbi=nulla&sem=eget&mauris=eros&laoreet=elementum	t	20296
69ae4d80-9136-460f-b1c5-abf34cdd1cb5	2024-07-09 22:56:28	81	45	\\x62363133623931353739376435663836316566343762616565393734323135393932633333336538656338363039336665613135363565396161633537323161	http://networkadvertising.org/lorem/vitae/mattis/nibh.json?pellentesque=blandit&viverra=non&pede=interdum&ac=in&diam=ante&cras=vestibulum&pellentesque=ante&volutpat=ipsum&dui=primis&maecenas=in&tristique=faucibus&est=orci&et=luctus&tempus=et&semper=ultrices&est=posuere&quam=cubilia&pharetra=curae&magna=duis&ac=faucibus&consequat=accumsan&metus=odio&sapien=curabitur&ut=convallis&nunc=duis&vestibulum=consequat&ante=dui&ipsum=nec&primis=nisi&in=volutpat&faucibus=eleifend&orci=donec&luctus=ut&et=dolor&ultrices=morbi&posuere=vel&cubilia=lectus&curae=in&mauris=quam&viverra=fringilla&diam=rhoncus&vitae=mauris&quam=enim&suspendisse=leo&potenti=rhoncus&nullam=sed&porttitor=vestibulum&lacus=sit&at=amet&turpis=cursus&donec=id&posuere=turpis&metus=integer&vitae=aliquet&ipsum=massa&aliquam=id&non=lobortis&mauris=convallis&morbi=tortor	t	48110
316fde0d-1a48-48e5-adea-76d3e21525bb	2024-04-26 20:00:10	70	46	\\x38373231393862633932326232383033326462306463623961633266653530653665616135353535373738323335323438303535653830636532303363306466	https://goo.ne.jp/parturient.html?nonummy=lorem&maecenas=quisque&tincidunt=ut&lacus=erat&at=curabitur&velit=gravida&vivamus=nisi&vel=at&nulla=nibh&eget=in&eros=hac&elementum=habitasse&pellentesque=platea&quisque=dictumst&porta=aliquam&volutpat=augue	t	57954
28279bd7-815d-42c2-a7a6-d999f19f415d	2024-06-27 22:52:07	60	90	\\x36616537303262393465303863643065313636626562333062643262303866376336633166393266643437383361383634366235323238386332343563333238	http://who.int/orci/luctus/et/ultrices/posuere/cubilia.xml?pellentesque=lectus&quisque=in&porta=quam&volutpat=fringilla&erat=rhoncus&quisque=mauris&erat=enim&eros=leo&viverra=rhoncus&eget=sed&congue=vestibulum&eget=sit&semper=amet&rutrum=cursus&nulla=id&nunc=turpis&purus=integer&phasellus=aliquet&in=massa&felis=id&donec=lobortis&semper=convallis&sapien=tortor&a=risus&libero=dapibus&nam=augue&dui=vel&proin=accumsan&leo=tellus&odio=nisi&porttitor=eu&id=orci&consequat=mauris&in=lacinia&consequat=sapien&ut=quis&nulla=libero&sed=nullam&accumsan=sit&felis=amet&ut=turpis&at=elementum&dolor=ligula&quis=vehicula&odio=consequat&consequat=morbi&varius=a&integer=ipsum&ac=integer&leo=a&pellentesque=nibh&ultrices=in&mattis=quis&odio=justo&donec=maecenas&vitae=rhoncus&nisi=aliquam&nam=lacus&ultrices=morbi&libero=quis&non=tortor&mattis=id&pulvinar=nulla&nulla=ultrices&pede=aliquet&ullamcorper=maecenas&augue=leo&a=odio&suscipit=condimentum&nulla=id&elit=luctus&ac=nec	f	44979
58c1b148-513c-4319-b08a-385f12befe47	2024-04-07 11:10:42	63	9	\\x63313561666334623431306135306634623333633664336330346465356237666131633531383830656534663735613239373263336432663537336638643036	https://istockphoto.com/platea/dictumst/morbi/vestibulum/velit.aspx?non=sodales&quam=sed&nec=tincidunt&dui=eu&luctus=felis&rutrum=fusce&nulla=posuere&tellus=felis&in=sed&sagittis=lacus&dui=morbi&vel=sem&nisl=mauris&duis=laoreet&ac=ut&nibh=rhoncus&fusce=aliquet&lacus=pulvinar&purus=sed&aliquet=nisl&at=nunc&feugiat=rhoncus&non=dui&pretium=vel&quis=sem&lectus=sed&suspendisse=sagittis&potenti=nam&in=congue&eleifend=risus&quam=semper&a=porta&odio=volutpat&in=quam&hac=pede&habitasse=lobortis&platea=ligula&dictumst=sit&maecenas=amet&ut=eleifend&massa=pede&quis=libero&augue=quis&luctus=orci&tincidunt=nullam&nulla=molestie&mollis=nibh&molestie=in&lorem=lectus&quisque=pellentesque&ut=at&erat=nulla&curabitur=suspendisse&gravida=potenti&nisi=cras&at=in&nibh=purus&in=eu&hac=magna&habitasse=vulputate&platea=luctus&dictumst=cum&aliquam=sociis&augue=natoque&quam=penatibus&sollicitudin=et&vitae=magnis&consectetuer=dis&eget=parturient&rutrum=montes&at=nascetur&lorem=ridiculus&integer=mus&tincidunt=vivamus&ante=vestibulum&vel=sagittis&ipsum=sapien&praesent=cum&blandit=sociis&lacinia=natoque&erat=penatibus&vestibulum=et&sed=magnis&magna=dis&at=parturient&nunc=montes&commodo=nascetur&placerat=ridiculus&praesent=mus&blandit=etiam&nam=vel&nulla=augue&integer=vestibulum&pede=rutrum&justo=rutrum&lacinia=neque&eget=aenean	t	14075
bee827f7-153f-4ea6-8560-c56c457a6dd8	2023-12-19 07:05:31	9	35	\\x30656164373332343961653562343962306638343631306333333938623831333931653162353461366639623132663930653132663863626230613436663633	http://cam.ac.uk/donec.aspx?orci=id&luctus=ligula&et=suspendisse&ultrices=ornare&posuere=consequat&cubilia=lectus&curae=in&nulla=est&dapibus=risus&dolor=auctor&vel=sed&est=tristique&donec=in&odio=tempus&justo=sit&sollicitudin=amet&ut=sem&suscipit=fusce&a=consequat&feugiat=nulla&et=nisl&eros=nunc&vestibulum=nisl&ac=duis&est=bibendum&lacinia=felis&nisi=sed&venenatis=interdum&tristique=venenatis&fusce=turpis&congue=enim&diam=blandit&id=mi&ornare=in&imperdiet=porttitor&sapien=pede&urna=justo&pretium=eu&nisl=massa&ut=donec&volutpat=dapibus&sapien=duis&arcu=at&sed=velit&augue=eu&aliquam=est&erat=congue&volutpat=elementum&in=in&congue=hac	t	27097
354ed58b-32c5-4aa8-b002-a771bf2a85cb	2023-11-08 16:09:43	20	84	\\x64366265626336643764383832656365373134333434303233366538306466306438333534636433636362636539346438343734626566383337656130363838	http://goo.ne.jp/nec/euismod/scelerisque/quam/turpis.html?primis=platea&in=dictumst&faucibus=aliquam&orci=augue&luctus=quam&et=sollicitudin&ultrices=vitae&posuere=consectetuer&cubilia=eget&curae=rutrum&donec=at&pharetra=lorem&magna=integer&vestibulum=tincidunt&aliquet=ante&ultrices=vel&erat=ipsum&tortor=praesent&sollicitudin=blandit&mi=lacinia&sit=erat&amet=vestibulum&lobortis=sed&sapien=magna&sapien=at&non=nunc&mi=commodo&integer=placerat&ac=praesent&neque=blandit&duis=nam&bibendum=nulla&morbi=integer&non=pede&quam=justo&nec=lacinia&dui=eget&luctus=tincidunt&rutrum=eget&nulla=tempus&tellus=vel&in=pede&sagittis=morbi	t	88694
9d049c58-229d-4ec8-9cdb-162b0d9f9345	2024-07-21 07:35:02	77	14	\\x34663833613761623930323730643239616536636131646262636165396637633062376234323361353635366635373431616564353061346435366561663936	https://chicagotribune.com/sodales.jsp?et=elementum&commodo=ligula&vulputate=vehicula&justo=consequat&in=morbi&blandit=a&ultrices=ipsum&enim=integer&lorem=a&ipsum=nibh&dolor=in&sit=quis&amet=justo&consectetuer=maecenas&adipiscing=rhoncus&elit=aliquam&proin=lacus&interdum=morbi&mauris=quis&non=tortor&ligula=id&pellentesque=nulla&ultrices=ultrices&phasellus=aliquet&id=maecenas&sapien=leo&in=odio&sapien=condimentum&iaculis=id&congue=luctus&vivamus=nec&metus=molestie&arcu=sed&adipiscing=justo&molestie=pellentesque&hendrerit=viverra&at=pede&vulputate=ac&vitae=diam&nisl=cras&aenean=pellentesque&lectus=volutpat&pellentesque=dui&eget=maecenas&nunc=tristique&donec=est&quis=et&orci=tempus&eget=semper&orci=est&vehicula=quam&condimentum=pharetra&curabitur=magna&in=ac&libero=consequat&ut=metus&massa=sapien&volutpat=ut&convallis=nunc&morbi=vestibulum&odio=ante&odio=ipsum&elementum=primis&eu=in&interdum=faucibus&eu=orci&tincidunt=luctus&in=et	f	21529
3fd3ebf8-5f0e-4f81-82ac-4093890c7db0	2024-04-25 23:31:42	4	36	\\x38353033336432623363626466613135633361326564356134373562313263396662343637633635643361386239306163313435656431383230643138323335	http://amazon.co.uk/suscipit/nulla.png?aenean=quis&lectus=orci&pellentesque=eget&eget=orci&nunc=vehicula&donec=condimentum&quis=curabitur&orci=in&eget=libero&orci=ut&vehicula=massa&condimentum=volutpat&curabitur=convallis&in=morbi&libero=odio&ut=odio&massa=elementum&volutpat=eu&convallis=interdum&morbi=eu&odio=tincidunt&odio=in&elementum=leo&eu=maecenas&interdum=pulvinar&eu=lobortis&tincidunt=est&in=phasellus&leo=sit&maecenas=amet&pulvinar=erat&lobortis=nulla&est=tempus&phasellus=vivamus	f	88873
b4d53818-aefd-4c80-bf50-dae0a23bc41f	2024-03-21 18:45:12	53	11	\\x36343764313661313931643434386230386361643965353536323030376663393432333063613838336131306330366232333639303538326366356331323632	https://sourceforge.net/in/tempor.xml?eu=tempus&massa=semper&donec=est&dapibus=quam&duis=pharetra&at=magna&velit=ac&eu=consequat&est=metus&congue=sapien&elementum=ut&in=nunc&hac=vestibulum&habitasse=ante&platea=ipsum&dictumst=primis&morbi=in&vestibulum=faucibus&velit=orci&id=luctus&pretium=et&iaculis=ultrices&diam=posuere&erat=cubilia&fermentum=curae&justo=mauris&nec=viverra&condimentum=diam&neque=vitae&sapien=quam&placerat=suspendisse&ante=potenti&nulla=nullam&justo=porttitor&aliquam=lacus&quis=at&turpis=turpis&eget=donec&elit=posuere&sodales=metus&scelerisque=vitae&mauris=ipsum&sit=aliquam&amet=non&eros=mauris&suspendisse=morbi&accumsan=non&tortor=lectus&quis=aliquam&turpis=sit&sed=amet&ante=diam&vivamus=in&tortor=magna&duis=bibendum&mattis=imperdiet&egestas=nullam&metus=orci&aenean=pede&fermentum=venenatis&donec=non&ut=sodales&mauris=sed&eget=tincidunt&massa=eu&tempor=felis&convallis=fusce&nulla=posuere&neque=felis&libero=sed&convallis=lacus&eget=morbi&eleifend=sem&luctus=mauris&ultricies=laoreet&eu=ut&nibh=rhoncus&quisque=aliquet&id=pulvinar&justo=sed&sit=nisl&amet=nunc&sapien=rhoncus&dignissim=dui&vestibulum=vel&vestibulum=sem&ante=sed&ipsum=sagittis&primis=nam&in=congue&faucibus=risus&orci=semper&luctus=porta&et=volutpat	t	13156
51c760af-1888-4309-b28c-6c72ba43c5a7	2024-04-22 06:49:49	34	91	\\x35363063356166353938313565366562656136316631343930643766356264626163633161396337346361323137356633613664653232396162386436323833	http://miibeian.gov.cn/auctor/gravida/sem.js?nibh=aenean&in=auctor&quis=gravida&justo=sem&maecenas=praesent&rhoncus=id&aliquam=massa&lacus=id&morbi=nisl&quis=venenatis&tortor=lacinia&id=aenean&nulla=sit&ultrices=amet&aliquet=justo&maecenas=morbi&leo=ut&odio=odio&condimentum=cras&id=mi&luctus=pede&nec=malesuada&molestie=in&sed=imperdiet&justo=et&pellentesque=commodo&viverra=vulputate&pede=justo&ac=in&diam=blandit&cras=ultrices&pellentesque=enim&volutpat=lorem&dui=ipsum&maecenas=dolor&tristique=sit&est=amet&et=consectetuer&tempus=adipiscing&semper=elit&est=proin&quam=interdum&pharetra=mauris&magna=non&ac=ligula&consequat=pellentesque&metus=ultrices&sapien=phasellus&ut=id&nunc=sapien&vestibulum=in&ante=sapien&ipsum=iaculis&primis=congue&in=vivamus&faucibus=metus&orci=arcu&luctus=adipiscing&et=molestie&ultrices=hendrerit&posuere=at&cubilia=vulputate&curae=vitae&mauris=nisl&viverra=aenean&diam=lectus&vitae=pellentesque&quam=eget&suspendisse=nunc&potenti=donec	t	72297
d5c9cd40-e0d2-4d29-8cb0-c16ac6e0c4aa	2024-01-04 21:12:15	96	68	\\x66623465313565643533653432313131303463643738633230613430643739636132663039393235376563366333373731653230363166613436626331656431	http://geocities.com/nulla/ultrices/aliquet/maecenas.xml?eu=ridiculus&interdum=mus&eu=vivamus&tincidunt=vestibulum&in=sagittis&leo=sapien&maecenas=cum&pulvinar=sociis&lobortis=natoque&est=penatibus&phasellus=et&sit=magnis&amet=dis&erat=parturient&nulla=montes&tempus=nascetur&vivamus=ridiculus&in=mus&felis=etiam&eu=vel&sapien=augue&cursus=vestibulum&vestibulum=rutrum&proin=rutrum&eu=neque&mi=aenean&nulla=auctor&ac=gravida&enim=sem&in=praesent&tempor=id&turpis=massa&nec=id&euismod=nisl&scelerisque=venenatis&quam=lacinia&turpis=aenean&adipiscing=sit&lorem=amet&vitae=justo&mattis=morbi&nibh=ut&ligula=odio&nec=cras&sem=mi&duis=pede&aliquam=malesuada&convallis=in&nunc=imperdiet&proin=et&at=commodo&turpis=vulputate&a=justo&pede=in&posuere=blandit&nonummy=ultrices&integer=enim&non=lorem&velit=ipsum	t	42414
275a4db2-d27e-4a05-9537-424932af3e1c	2024-04-13 07:39:18	14	26	\\x36366239333632313837643739363961666538383366336466636639316666306162636139373261386365343534333533396434663365363332356432313833	http://ibm.com/penatibus/et/magnis/dis/parturient/montes.aspx?sed=potenti&ante=cras&vivamus=in&tortor=purus&duis=eu&mattis=magna&egestas=vulputate&metus=luctus&aenean=cum&fermentum=sociis&donec=natoque&ut=penatibus&mauris=et&eget=magnis&massa=dis&tempor=parturient&convallis=montes&nulla=nascetur&neque=ridiculus&libero=mus&convallis=vivamus&eget=vestibulum&eleifend=sagittis&luctus=sapien&ultricies=cum&eu=sociis&nibh=natoque&quisque=penatibus&id=et&justo=magnis&sit=dis&amet=parturient&sapien=montes&dignissim=nascetur&vestibulum=ridiculus&vestibulum=mus&ante=etiam&ipsum=vel&primis=augue&in=vestibulum&faucibus=rutrum&orci=rutrum&luctus=neque&et=aenean&ultrices=auctor&posuere=gravida&cubilia=sem&curae=praesent&nulla=id&dapibus=massa&dolor=id&vel=nisl&est=venenatis&donec=lacinia&odio=aenean&justo=sit&sollicitudin=amet&ut=justo&suscipit=morbi&a=ut&feugiat=odio&et=cras&eros=mi&vestibulum=pede&ac=malesuada&est=in&lacinia=imperdiet&nisi=et&venenatis=commodo&tristique=vulputate&fusce=justo&congue=in&diam=blandit&id=ultrices&ornare=enim&imperdiet=lorem&sapien=ipsum&urna=dolor&pretium=sit&nisl=amet&ut=consectetuer&volutpat=adipiscing&sapien=elit&arcu=proin&sed=interdum&augue=mauris&aliquam=non&erat=ligula&volutpat=pellentesque&in=ultrices&congue=phasellus&etiam=id&justo=sapien	t	41157
e7c10140-11fd-4181-b382-ff4101340373	2024-05-08 04:34:24	93	38	\\x65396434626235343865616639653334373664363237623239356164356561316531663364386632393538626463666135323330653066393932616434643463	https://arizona.edu/varius/ut.jpg?duis=vivamus&faucibus=vestibulum&accumsan=sagittis&odio=sapien&curabitur=cum&convallis=sociis&duis=natoque&consequat=penatibus&dui=et&nec=magnis&nisi=dis&volutpat=parturient&eleifend=montes&donec=nascetur&ut=ridiculus&dolor=mus&morbi=etiam&vel=vel&lectus=augue&in=vestibulum&quam=rutrum&fringilla=rutrum&rhoncus=neque&mauris=aenean&enim=auctor&leo=gravida&rhoncus=sem&sed=praesent&vestibulum=id&sit=massa&amet=id&cursus=nisl&id=venenatis&turpis=lacinia&integer=aenean&aliquet=sit&massa=amet&id=justo&lobortis=morbi&convallis=ut&tortor=odio&risus=cras&dapibus=mi&augue=pede&vel=malesuada&accumsan=in&tellus=imperdiet&nisi=et&eu=commodo&orci=vulputate&mauris=justo&lacinia=in	t	51476
ce6f1627-5a01-4644-87fa-cac6dca8d158	2023-11-25 22:47:50	90	84	\\x35373564383734633864373764343063353862323133393131626463323938306632376365356539633930313764393965313531313036303135666431383138	http://un.org/pede.html?integer=at&a=turpis&nibh=donec&in=posuere&quis=metus&justo=vitae&maecenas=ipsum&rhoncus=aliquam&aliquam=non&lacus=mauris&morbi=morbi&quis=non&tortor=lectus&id=aliquam	f	49020
44e60dc6-4808-4933-aa49-d0eaf18138e9	2023-12-19 17:24:48	27	39	\\x66376238616663376433636235313364616632396666303736663430336331326234356565363864303733383835366238333339393161376462393866633064	http://free.fr/lorem/quisque/ut/erat/curabitur/gravida/nisi.png?in=adipiscing&tempor=lorem&turpis=vitae&nec=mattis&euismod=nibh&scelerisque=ligula&quam=nec&turpis=sem&adipiscing=duis&lorem=aliquam&vitae=convallis&mattis=nunc&nibh=proin&ligula=at&nec=turpis&sem=a&duis=pede&aliquam=posuere&convallis=nonummy&nunc=integer&proin=non&at=velit&turpis=donec&a=diam&pede=neque&posuere=vestibulum&nonummy=eget&integer=vulputate&non=ut&velit=ultrices&donec=vel&diam=augue&neque=vestibulum&vestibulum=ante&eget=ipsum&vulputate=primis&ut=in&ultrices=faucibus&vel=orci&augue=luctus&vestibulum=et&ante=ultrices&ipsum=posuere&primis=cubilia&in=curae&faucibus=donec&orci=pharetra&luctus=magna&et=vestibulum&ultrices=aliquet&posuere=ultrices&cubilia=erat&curae=tortor&donec=sollicitudin&pharetra=mi&magna=sit&vestibulum=amet&aliquet=lobortis&ultrices=sapien&erat=sapien&tortor=non	f	87151
ce73ea30-a02d-47fd-8780-7ea398f64712	2023-12-27 15:23:42	71	25	\\x35653466393835306561363965303730633434346535396531633436663438663733633639323436653138633365323134613736323031303933353539653363	https://nih.gov/sed/tristique/in/tempus.aspx?convallis=justo&duis=nec&consequat=condimentum&dui=neque&nec=sapien&nisi=placerat&volutpat=ante&eleifend=nulla&donec=justo&ut=aliquam&dolor=quis&morbi=turpis&vel=eget&lectus=elit&in=sodales&quam=scelerisque&fringilla=mauris&rhoncus=sit&mauris=amet&enim=eros&leo=suspendisse&rhoncus=accumsan&sed=tortor&vestibulum=quis&sit=turpis&amet=sed&cursus=ante&id=vivamus&turpis=tortor&integer=duis&aliquet=mattis&massa=egestas&id=metus&lobortis=aenean&convallis=fermentum&tortor=donec&risus=ut&dapibus=mauris&augue=eget&vel=massa&accumsan=tempor&tellus=convallis&nisi=nulla&eu=neque&orci=libero&mauris=convallis&lacinia=eget&sapien=eleifend&quis=luctus&libero=ultricies&nullam=eu&sit=nibh&amet=quisque&turpis=id&elementum=justo&ligula=sit&vehicula=amet&consequat=sapien&morbi=dignissim&a=vestibulum&ipsum=vestibulum&integer=ante&a=ipsum&nibh=primis&in=in&quis=faucibus&justo=orci&maecenas=luctus&rhoncus=et&aliquam=ultrices&lacus=posuere&morbi=cubilia&quis=curae&tortor=nulla&id=dapibus&nulla=dolor&ultrices=vel&aliquet=est&maecenas=donec&leo=odio&odio=justo&condimentum=sollicitudin&id=ut&luctus=suscipit&nec=a&molestie=feugiat&sed=et&justo=eros&pellentesque=vestibulum&viverra=ac&pede=est&ac=lacinia&diam=nisi&cras=venenatis&pellentesque=tristique&volutpat=fusce	t	20083
4202c24a-f90d-43d5-aa2a-5d38327f5ee7	2024-06-05 20:53:15	38	40	\\x36626331373734363130363937383362636162653136616462366532353066393163656462623737613531343362656261303261396134393266356631323931	https://cam.ac.uk/molestie/lorem/quisque/ut/erat.jsp?pharetra=sit&magna=amet&ac=diam&consequat=in&metus=magna&sapien=bibendum&ut=imperdiet&nunc=nullam&vestibulum=orci&ante=pede&ipsum=venenatis&primis=non&in=sodales&faucibus=sed&orci=tincidunt&luctus=eu&et=felis&ultrices=fusce&posuere=posuere&cubilia=felis&curae=sed&mauris=lacus&viverra=morbi&diam=sem&vitae=mauris&quam=laoreet&suspendisse=ut&potenti=rhoncus&nullam=aliquet&porttitor=pulvinar&lacus=sed&at=nisl&turpis=nunc&donec=rhoncus&posuere=dui&metus=vel&vitae=sem&ipsum=sed&aliquam=sagittis&non=nam&mauris=congue&morbi=risus&non=semper&lectus=porta&aliquam=volutpat&sit=quam&amet=pede&diam=lobortis&in=ligula&magna=sit&bibendum=amet&imperdiet=eleifend&nullam=pede&orci=libero&pede=quis&venenatis=orci&non=nullam&sodales=molestie&sed=nibh&tincidunt=in&eu=lectus&felis=pellentesque&fusce=at&posuere=nulla&felis=suspendisse&sed=potenti&lacus=cras&morbi=in	f	33412
8e028a64-e408-444d-a608-fa2d106fd195	2024-06-02 21:46:58	28	14	\\x34356464633866663730363735653430626333643335633431666438343533313766373762386434383138313466353539346565346332353035306232646362	https://state.tx.us/orci/luctus/et/ultrices/posuere.aspx?cras=in&in=quis&purus=justo&eu=maecenas&magna=rhoncus&vulputate=aliquam&luctus=lacus&cum=morbi&sociis=quis&natoque=tortor&penatibus=id&et=nulla&magnis=ultrices&dis=aliquet&parturient=maecenas&montes=leo&nascetur=odio&ridiculus=condimentum&mus=id&vivamus=luctus&vestibulum=nec&sagittis=molestie&sapien=sed&cum=justo&sociis=pellentesque&natoque=viverra&penatibus=pede&et=ac&magnis=diam&dis=cras&parturient=pellentesque&montes=volutpat&nascetur=dui&ridiculus=maecenas&mus=tristique&etiam=est&vel=et&augue=tempus	t	6420
1ebdf3ce-e494-4c3e-a790-c86bc08e4d67	2024-01-07 10:15:45	44	58	\\x33326231353238633237343666303165613130666638333634366563643262316137663463303461343139306633353034646532663063646563303139373964	http://github.io/pretium.html?potenti=turpis&nullam=a&porttitor=pede&lacus=posuere&at=nonummy&turpis=integer&donec=non&posuere=velit&metus=donec&vitae=diam&ipsum=neque&aliquam=vestibulum&non=eget&mauris=vulputate&morbi=ut&non=ultrices&lectus=vel&aliquam=augue&sit=vestibulum&amet=ante&diam=ipsum&in=primis&magna=in&bibendum=faucibus&imperdiet=orci&nullam=luctus&orci=et&pede=ultrices&venenatis=posuere&non=cubilia&sodales=curae	t	71122
ac8225ee-d339-43ad-a225-5e62372ef759	2024-07-14 05:19:02	1	47	\\x30613336666161363065613665626163653937373032353234323832346333623935333861363266346438646232633465353439303332343130363934313265	https://msu.edu/turpis/integer/aliquet/massa/id/lobortis.js?nibh=in&fusce=hac&lacus=habitasse&purus=platea&aliquet=dictumst&at=maecenas&feugiat=ut&non=massa&pretium=quis&quis=augue&lectus=luctus&suspendisse=tincidunt&potenti=nulla&in=mollis&eleifend=molestie&quam=lorem&a=quisque&odio=ut&in=erat&hac=curabitur&habitasse=gravida&platea=nisi&dictumst=at&maecenas=nibh&ut=in&massa=hac&quis=habitasse&augue=platea&luctus=dictumst&tincidunt=aliquam&nulla=augue&mollis=quam&molestie=sollicitudin&lorem=vitae&quisque=consectetuer&ut=eget&erat=rutrum&curabitur=at&gravida=lorem&nisi=integer&at=tincidunt&nibh=ante&in=vel&hac=ipsum&habitasse=praesent&platea=blandit&dictumst=lacinia&aliquam=erat&augue=vestibulum&quam=sed&sollicitudin=magna&vitae=at	t	79351
43619229-320c-46b5-bbac-a4f471d08dfc	2024-03-23 09:23:16	70	7	\\x32356364383962636261326433396237653431356631316365303535363439643165356438333361306539653731393936393735646435323036336635313430	https://examiner.com/eget/tincidunt.png?pulvinar=tempus&sed=vel&nisl=pede&nunc=morbi&rhoncus=porttitor&dui=lorem&vel=id&sem=ligula&sed=suspendisse&sagittis=ornare&nam=consequat&congue=lectus&risus=in&semper=est&porta=risus&volutpat=auctor&quam=sed&pede=tristique&lobortis=in&ligula=tempus&sit=sit&amet=amet&eleifend=sem&pede=fusce&libero=consequat&quis=nulla&orci=nisl&nullam=nunc&molestie=nisl&nibh=duis&in=bibendum&lectus=felis&pellentesque=sed&at=interdum&nulla=venenatis&suspendisse=turpis&potenti=enim&cras=blandit&in=mi&purus=in&eu=porttitor&magna=pede&vulputate=justo&luctus=eu&cum=massa&sociis=donec&natoque=dapibus&penatibus=duis&et=at&magnis=velit&dis=eu&parturient=est&montes=congue&nascetur=elementum&ridiculus=in&mus=hac&vivamus=habitasse&vestibulum=platea&sagittis=dictumst&sapien=morbi&cum=vestibulum&sociis=velit&natoque=id&penatibus=pretium&et=iaculis&magnis=diam&dis=erat&parturient=fermentum&montes=justo&nascetur=nec&ridiculus=condimentum&mus=neque&etiam=sapien&vel=placerat&augue=ante&vestibulum=nulla&rutrum=justo&rutrum=aliquam&neque=quis&aenean=turpis&auctor=eget	t	26016
cd66b88c-50c7-4ca8-b276-9532b0ebbca2	2024-05-21 15:21:42	94	94	\\x37633036633637313635303236666132393139623061663732373861306436366237613133346665383661353133646564383561633366663439323535666132	http://last.fm/adipiscing/elit.jsp?iaculis=fusce&justo=posuere&in=felis&hac=sed&habitasse=lacus&platea=morbi&dictumst=sem&etiam=mauris&faucibus=laoreet&cursus=ut&urna=rhoncus&ut=aliquet&tellus=pulvinar&nulla=sed&ut=nisl&erat=nunc&id=rhoncus&mauris=dui&vulputate=vel&elementum=sem&nullam=sed&varius=sagittis&nulla=nam&facilisi=congue&cras=risus&non=semper&velit=porta&nec=volutpat&nisi=quam&vulputate=pede&nonummy=lobortis&maecenas=ligula&tincidunt=sit&lacus=amet&at=eleifend&velit=pede&vivamus=libero&vel=quis&nulla=orci&eget=nullam&eros=molestie	t	83748
9ff3816d-03e2-49cd-98e0-e558f15df6d6	2024-05-27 08:18:37	56	51	\\x32613530396133653539376233396461383162326239366236363433643931386535663662363130393862663066633030616262643235626361666532383738	http://google.ca/sagittis/nam/congue.jpg?quis=enim&tortor=leo&id=rhoncus&nulla=sed&ultrices=vestibulum&aliquet=sit&maecenas=amet&leo=cursus&odio=id&condimentum=turpis&id=integer&luctus=aliquet&nec=massa&molestie=id&sed=lobortis&justo=convallis&pellentesque=tortor&viverra=risus&pede=dapibus&ac=augue&diam=vel&cras=accumsan	t	99123
b8018acc-9aef-4b73-9a4e-e01d84d9f318	2024-02-20 17:29:33	95	7	\\x64393266623761313833663261303638396163353266326462646563613131656337313630343964386339646366366537656632326364643561353865356535	https://usa.gov/ipsum/dolor.html?massa=elit&id=sodales&lobortis=scelerisque&convallis=mauris&tortor=sit&risus=amet&dapibus=eros&augue=suspendisse&vel=accumsan&accumsan=tortor&tellus=quis&nisi=turpis&eu=sed&orci=ante&mauris=vivamus&lacinia=tortor&sapien=duis&quis=mattis&libero=egestas&nullam=metus&sit=aenean&amet=fermentum&turpis=donec&elementum=ut&ligula=mauris&vehicula=eget&consequat=massa&morbi=tempor&a=convallis&ipsum=nulla&integer=neque&a=libero&nibh=convallis&in=eget&quis=eleifend&justo=luctus&maecenas=ultricies&rhoncus=eu&aliquam=nibh&lacus=quisque&morbi=id&quis=justo&tortor=sit&id=amet&nulla=sapien&ultrices=dignissim&aliquet=vestibulum&maecenas=vestibulum&leo=ante&odio=ipsum&condimentum=primis&id=in&luctus=faucibus&nec=orci&molestie=luctus&sed=et&justo=ultrices&pellentesque=posuere&viverra=cubilia&pede=curae&ac=nulla&diam=dapibus&cras=dolor&pellentesque=vel&volutpat=est&dui=donec&maecenas=odio&tristique=justo&est=sollicitudin&et=ut&tempus=suscipit&semper=a&est=feugiat&quam=et&pharetra=eros&magna=vestibulum&ac=ac&consequat=est&metus=lacinia&sapien=nisi&ut=venenatis&nunc=tristique&vestibulum=fusce&ante=congue&ipsum=diam&primis=id&in=ornare&faucibus=imperdiet&orci=sapien&luctus=urna&et=pretium&ultrices=nisl&posuere=ut&cubilia=volutpat&curae=sapien&mauris=arcu&viverra=sed&diam=augue&vitae=aliquam	t	55481
d1e5f0c9-6cab-43de-ba2c-bb7d59270c31	2024-01-10 13:27:41	27	33	\\x36643264393038663033613136613966616437663034343335333234376664613632333664636432356365313862626633306463633333366565656636323561	https://arizona.edu/aenean.png?sollicitudin=consequat&vitae=dui&consectetuer=nec&eget=nisi&rutrum=volutpat&at=eleifend&lorem=donec&integer=ut&tincidunt=dolor&ante=morbi&vel=vel&ipsum=lectus&praesent=in&blandit=quam&lacinia=fringilla&erat=rhoncus&vestibulum=mauris&sed=enim&magna=leo&at=rhoncus&nunc=sed&commodo=vestibulum&placerat=sit&praesent=amet&blandit=cursus&nam=id&nulla=turpis&integer=integer&pede=aliquet&justo=massa&lacinia=id&eget=lobortis&tincidunt=convallis&eget=tortor&tempus=risus&vel=dapibus&pede=augue&morbi=vel&porttitor=accumsan&lorem=tellus&id=nisi&ligula=eu&suspendisse=orci&ornare=mauris&consequat=lacinia&lectus=sapien&in=quis&est=libero&risus=nullam&auctor=sit&sed=amet&tristique=turpis&in=elementum&tempus=ligula&sit=vehicula&amet=consequat&sem=morbi&fusce=a&consequat=ipsum&nulla=integer&nisl=a&nunc=nibh&nisl=in&duis=quis&bibendum=justo&felis=maecenas&sed=rhoncus&interdum=aliquam&venenatis=lacus&turpis=morbi&enim=quis&blandit=tortor&mi=id&in=nulla&porttitor=ultrices&pede=aliquet	t	79351
d9071722-e23b-43c2-aa3e-1c8b94bf7366	2024-03-31 15:25:23	83	84	\\x38373231383163383436303230646134343730383362376139633437383633346439313236626139393966313566656535313934323832646234343961356335	http://nba.com/at/nulla/suspendisse.jsp?lorem=nisi&integer=at&tincidunt=nibh&ante=in&vel=hac&ipsum=habitasse&praesent=platea&blandit=dictumst&lacinia=aliquam&erat=augue&vestibulum=quam&sed=sollicitudin&magna=vitae&at=consectetuer&nunc=eget&commodo=rutrum&placerat=at&praesent=lorem&blandit=integer&nam=tincidunt&nulla=ante&integer=vel&pede=ipsum&justo=praesent&lacinia=blandit&eget=lacinia&tincidunt=erat&eget=vestibulum&tempus=sed&vel=magna&pede=at&morbi=nunc&porttitor=commodo	f	62866
3690ea3a-a63d-41c8-807f-f223159c9f1f	2024-08-11 05:19:26	4	56	\\x61613232386361333665613461313937333131613462653265323438633961363131613430633035633535333437333531613736396361393165616565616265	https://irs.gov/congue.json?lorem=eros&vitae=viverra&mattis=eget&nibh=congue&ligula=eget&nec=semper&sem=rutrum&duis=nulla&aliquam=nunc&convallis=purus&nunc=phasellus&proin=in&at=felis&turpis=donec&a=semper&pede=sapien&posuere=a&nonummy=libero&integer=nam&non=dui&velit=proin&donec=leo&diam=odio&neque=porttitor&vestibulum=id&eget=consequat&vulputate=in&ut=consequat&ultrices=ut&vel=nulla&augue=sed&vestibulum=accumsan&ante=felis&ipsum=ut&primis=at&in=dolor&faucibus=quis&orci=odio&luctus=consequat&et=varius&ultrices=integer&posuere=ac&cubilia=leo&curae=pellentesque&donec=ultrices&pharetra=mattis&magna=odio&vestibulum=donec&aliquet=vitae&ultrices=nisi&erat=nam&tortor=ultrices&sollicitudin=libero&mi=non&sit=mattis&amet=pulvinar&lobortis=nulla&sapien=pede&sapien=ullamcorper&non=augue&mi=a&integer=suscipit&ac=nulla&neque=elit&duis=ac&bibendum=nulla&morbi=sed&non=vel&quam=enim&nec=sit&dui=amet&luctus=nunc&rutrum=viverra&nulla=dapibus&tellus=nulla&in=suscipit&sagittis=ligula&dui=in&vel=lacus&nisl=curabitur&duis=at&ac=ipsum&nibh=ac&fusce=tellus&lacus=semper&purus=interdum&aliquet=mauris&at=ullamcorper	f	74911
6fdc1e11-0f32-4d07-98ba-93573b3f524c	2024-10-03 05:13:45	13	68	\\x31356661383337356663326437303364373466373537363861306530353432616665333530383130616439353266656561643332663034343634396238346632	http://businessinsider.com/vestibulum/ante/ipsum.png?vulputate=nullam&elementum=sit&nullam=amet&varius=turpis&nulla=elementum&facilisi=ligula&cras=vehicula&non=consequat&velit=morbi&nec=a&nisi=ipsum&vulputate=integer&nonummy=a&maecenas=nibh&tincidunt=in&lacus=quis&at=justo&velit=maecenas&vivamus=rhoncus&vel=aliquam&nulla=lacus&eget=morbi&eros=quis&elementum=tortor&pellentesque=id&quisque=nulla&porta=ultrices&volutpat=aliquet&erat=maecenas&quisque=leo&erat=odio&eros=condimentum&viverra=id&eget=luctus&congue=nec&eget=molestie&semper=sed&rutrum=justo&nulla=pellentesque&nunc=viverra&purus=pede&phasellus=ac&in=diam&felis=cras&donec=pellentesque&semper=volutpat&sapien=dui	f	57237
43660367-7831-44f9-903e-4761f20b1a7b	2024-09-14 01:20:43	92	43	\\x63326634353636393635643733323861396239633630666664656162373764373430373164316630396530393132353538646661626330306164646139313839	http://biglobe.ne.jp/sed/justo/pellentesque/viverra/pede.png?ut=diam&volutpat=in&sapien=magna&arcu=bibendum&sed=imperdiet&augue=nullam&aliquam=orci&erat=pede&volutpat=venenatis&in=non&congue=sodales&etiam=sed&justo=tincidunt&etiam=eu&pretium=felis&iaculis=fusce&justo=posuere&in=felis&hac=sed&habitasse=lacus&platea=morbi&dictumst=sem&etiam=mauris&faucibus=laoreet&cursus=ut&urna=rhoncus&ut=aliquet&tellus=pulvinar&nulla=sed&ut=nisl&erat=nunc&id=rhoncus&mauris=dui&vulputate=vel&elementum=sem&nullam=sed&varius=sagittis&nulla=nam&facilisi=congue&cras=risus&non=semper&velit=porta&nec=volutpat&nisi=quam&vulputate=pede&nonummy=lobortis&maecenas=ligula&tincidunt=sit&lacus=amet&at=eleifend&velit=pede&vivamus=libero&vel=quis&nulla=orci&eget=nullam&eros=molestie&elementum=nibh&pellentesque=in&quisque=lectus&porta=pellentesque&volutpat=at&erat=nulla&quisque=suspendisse&erat=potenti&eros=cras&viverra=in&eget=purus&congue=eu&eget=magna&semper=vulputate&rutrum=luctus&nulla=cum&nunc=sociis&purus=natoque&phasellus=penatibus&in=et	f	33975
71b8026a-3596-4d44-bc8e-7f9bdf6e4942	2024-03-24 12:42:01	57	64	\\x61653832376131393562616635663138393735353462313464363033393733383233613739646136316537393430316531363262326666343430373234626137	https://stanford.edu/nec/dui/luctus/rutrum/nulla.png?in=pede&tempor=justo&turpis=eu&nec=massa&euismod=donec&scelerisque=dapibus&quam=duis&turpis=at&adipiscing=velit&lorem=eu&vitae=est&mattis=congue&nibh=elementum&ligula=in&nec=hac&sem=habitasse&duis=platea&aliquam=dictumst&convallis=morbi&nunc=vestibulum&proin=velit&at=id&turpis=pretium&a=iaculis&pede=diam&posuere=erat&nonummy=fermentum&integer=justo&non=nec&velit=condimentum&donec=neque&diam=sapien&neque=placerat&vestibulum=ante&eget=nulla&vulputate=justo&ut=aliquam&ultrices=quis&vel=turpis&augue=eget&vestibulum=elit&ante=sodales&ipsum=scelerisque&primis=mauris&in=sit&faucibus=amet&orci=eros&luctus=suspendisse&et=accumsan&ultrices=tortor&posuere=quis&cubilia=turpis&curae=sed&donec=ante&pharetra=vivamus&magna=tortor&vestibulum=duis&aliquet=mattis&ultrices=egestas&erat=metus&tortor=aenean&sollicitudin=fermentum&mi=donec&sit=ut&amet=mauris&lobortis=eget&sapien=massa&sapien=tempor&non=convallis&mi=nulla&integer=neque&ac=libero&neque=convallis&duis=eget&bibendum=eleifend&morbi=luctus&non=ultricies&quam=eu&nec=nibh&dui=quisque&luctus=id&rutrum=justo&nulla=sit&tellus=amet&in=sapien&sagittis=dignissim&dui=vestibulum&vel=vestibulum&nisl=ante&duis=ipsum&ac=primis&nibh=in&fusce=faucibus&lacus=orci	t	48616
d21abf58-b53c-4f6b-a0e7-96183b854457	2024-06-03 03:57:44	4	75	\\x61326361653065643762613464633431383265386335616366653063653539333239333439663964656463393363363466663566653939376264663037303339	http://blogs.com/mauris/morbi/non/lectus/aliquam/sit/amet.jsp?mi=sollicitudin&integer=vitae&ac=consectetuer&neque=eget&duis=rutrum&bibendum=at&morbi=lorem&non=integer&quam=tincidunt&nec=ante&dui=vel&luctus=ipsum&rutrum=praesent&nulla=blandit&tellus=lacinia&in=erat&sagittis=vestibulum&dui=sed&vel=magna&nisl=at&duis=nunc&ac=commodo&nibh=placerat&fusce=praesent&lacus=blandit&purus=nam&aliquet=nulla&at=integer&feugiat=pede&non=justo&pretium=lacinia&quis=eget&lectus=tincidunt&suspendisse=eget&potenti=tempus&in=vel&eleifend=pede&quam=morbi&a=porttitor&odio=lorem&in=id&hac=ligula&habitasse=suspendisse&platea=ornare&dictumst=consequat&maecenas=lectus&ut=in&massa=est&quis=risus&augue=auctor&luctus=sed&tincidunt=tristique&nulla=in&mollis=tempus&molestie=sit&lorem=amet&quisque=sem&ut=fusce&erat=consequat&curabitur=nulla&gravida=nisl&nisi=nunc&at=nisl&nibh=duis&in=bibendum&hac=felis&habitasse=sed&platea=interdum&dictumst=venenatis&aliquam=turpis&augue=enim&quam=blandit&sollicitudin=mi&vitae=in&consectetuer=porttitor&eget=pede&rutrum=justo&at=eu&lorem=massa&integer=donec&tincidunt=dapibus&ante=duis&vel=at&ipsum=velit&praesent=eu&blandit=est&lacinia=congue&erat=elementum	f	74016
47a15f21-a98f-494d-9ee4-014f46e06893	2024-04-23 04:46:49	38	52	\\x35396431333334316438626130383232393064383131303034623938396135306332613338616262333461626132666563336435323335643437326435303737	http://fema.gov/rhoncus/sed/vestibulum/sit.html?sapien=a&dignissim=pede&vestibulum=posuere&vestibulum=nonummy&ante=integer&ipsum=non&primis=velit&in=donec&faucibus=diam&orci=neque&luctus=vestibulum&et=eget&ultrices=vulputate&posuere=ut&cubilia=ultrices&curae=vel&nulla=augue&dapibus=vestibulum&dolor=ante&vel=ipsum&est=primis&donec=in&odio=faucibus&justo=orci&sollicitudin=luctus&ut=et&suscipit=ultrices&a=posuere&feugiat=cubilia&et=curae&eros=donec&vestibulum=pharetra&ac=magna&est=vestibulum&lacinia=aliquet&nisi=ultrices&venenatis=erat&tristique=tortor&fusce=sollicitudin&congue=mi&diam=sit&id=amet&ornare=lobortis&imperdiet=sapien&sapien=sapien&urna=non&pretium=mi&nisl=integer&ut=ac&volutpat=neque&sapien=duis&arcu=bibendum&sed=morbi&augue=non&aliquam=quam&erat=nec&volutpat=dui&in=luctus&congue=rutrum&etiam=nulla&justo=tellus&etiam=in&pretium=sagittis&iaculis=dui&justo=vel&in=nisl&hac=duis&habitasse=ac&platea=nibh&dictumst=fusce&etiam=lacus&faucibus=purus&cursus=aliquet&urna=at&ut=feugiat	f	23412
e2d28848-9849-4e1d-ba0a-097d7d604859	2024-02-03 01:04:49	62	10	\\x39343765613238366338383865363435613336633361616266336532396665333734313237303831633930356261343333646332303237343662636136386337	https://youtube.com/eu/sapien/cursus/vestibulum/proin/eu/mi.jpg?quis=auctor&turpis=gravida&sed=sem&ante=praesent&vivamus=id&tortor=massa&duis=id&mattis=nisl&egestas=venenatis&metus=lacinia&aenean=aenean&fermentum=sit&donec=amet&ut=justo&mauris=morbi&eget=ut&massa=odio&tempor=cras&convallis=mi&nulla=pede&neque=malesuada&libero=in&convallis=imperdiet&eget=et&eleifend=commodo&luctus=vulputate&ultricies=justo&eu=in&nibh=blandit&quisque=ultrices&id=enim&justo=lorem&sit=ipsum&amet=dolor&sapien=sit&dignissim=amet&vestibulum=consectetuer&vestibulum=adipiscing&ante=elit&ipsum=proin&primis=interdum&in=mauris&faucibus=non&orci=ligula&luctus=pellentesque&et=ultrices&ultrices=phasellus&posuere=id&cubilia=sapien&curae=in&nulla=sapien&dapibus=iaculis&dolor=congue&vel=vivamus&est=metus&donec=arcu&odio=adipiscing&justo=molestie&sollicitudin=hendrerit&ut=at&suscipit=vulputate&a=vitae&feugiat=nisl&et=aenean&eros=lectus&vestibulum=pellentesque&ac=eget&est=nunc&lacinia=donec&nisi=quis&venenatis=orci&tristique=eget&fusce=orci&congue=vehicula&diam=condimentum&id=curabitur&ornare=in&imperdiet=libero&sapien=ut&urna=massa&pretium=volutpat&nisl=convallis&ut=morbi&volutpat=odio&sapien=odio&arcu=elementum&sed=eu&augue=interdum&aliquam=eu&erat=tincidunt&volutpat=in&in=leo&congue=maecenas&etiam=pulvinar&justo=lobortis&etiam=est&pretium=phasellus&iaculis=sit	t	81094
b630349e-cc0e-47d8-a114-833fc730ffb1	2024-10-11 08:21:59	96	55	\\x31613030333435373537326161346134323235643366653263616661383331373233653636373162306433616232383634646638613066656131643965353735	https://samsung.com/etiam.js?montes=placerat&nascetur=ante&ridiculus=nulla&mus=justo&etiam=aliquam&vel=quis&augue=turpis&vestibulum=eget&rutrum=elit&rutrum=sodales&neque=scelerisque&aenean=mauris&auctor=sit&gravida=amet&sem=eros&praesent=suspendisse&id=accumsan&massa=tortor&id=quis&nisl=turpis&venenatis=sed&lacinia=ante&aenean=vivamus&sit=tortor&amet=duis&justo=mattis&morbi=egestas&ut=metus&odio=aenean&cras=fermentum&mi=donec&pede=ut&malesuada=mauris&in=eget&imperdiet=massa&et=tempor&commodo=convallis&vulputate=nulla&justo=neque&in=libero&blandit=convallis&ultrices=eget&enim=eleifend&lorem=luctus&ipsum=ultricies&dolor=eu&sit=nibh&amet=quisque&consectetuer=id&adipiscing=justo&elit=sit&proin=amet&interdum=sapien&mauris=dignissim&non=vestibulum&ligula=vestibulum&pellentesque=ante&ultrices=ipsum&phasellus=primis&id=in&sapien=faucibus&in=orci&sapien=luctus&iaculis=et&congue=ultrices&vivamus=posuere&metus=cubilia&arcu=curae&adipiscing=nulla&molestie=dapibus&hendrerit=dolor&at=vel&vulputate=est	f	4101
075281ab-a70f-4b3f-8869-05bca711fa67	2024-08-20 01:50:08	42	28	\\x30363836633138653334373365656434636431343364376438643062386635386465653139356162393238336332356138383963633064393461363131323536	https://cbc.ca/nulla.js?malesuada=aliquam&in=non&imperdiet=mauris&et=morbi&commodo=non&vulputate=lectus&justo=aliquam&in=sit&blandit=amet&ultrices=diam&enim=in&lorem=magna&ipsum=bibendum&dolor=imperdiet&sit=nullam&amet=orci&consectetuer=pede&adipiscing=venenatis&elit=non&proin=sodales&interdum=sed&mauris=tincidunt&non=eu&ligula=felis&pellentesque=fusce&ultrices=posuere&phasellus=felis&id=sed&sapien=lacus&in=morbi&sapien=sem&iaculis=mauris&congue=laoreet&vivamus=ut&metus=rhoncus&arcu=aliquet&adipiscing=pulvinar&molestie=sed&hendrerit=nisl&at=nunc&vulputate=rhoncus&vitae=dui&nisl=vel&aenean=sem&lectus=sed&pellentesque=sagittis&eget=nam&nunc=congue&donec=risus&quis=semper&orci=porta&eget=volutpat&orci=quam&vehicula=pede&condimentum=lobortis&curabitur=ligula&in=sit&libero=amet&ut=eleifend&massa=pede&volutpat=libero&convallis=quis&morbi=orci&odio=nullam&odio=molestie&elementum=nibh&eu=in&interdum=lectus&eu=pellentesque&tincidunt=at&in=nulla&leo=suspendisse&maecenas=potenti&pulvinar=cras&lobortis=in&est=purus&phasellus=eu&sit=magna&amet=vulputate&erat=luctus&nulla=cum&tempus=sociis&vivamus=natoque&in=penatibus&felis=et&eu=magnis&sapien=dis&cursus=parturient&vestibulum=montes&proin=nascetur&eu=ridiculus&mi=mus&nulla=vivamus&ac=vestibulum&enim=sagittis&in=sapien&tempor=cum&turpis=sociis	t	30794
a112fd46-a09e-4523-8baf-0bf93e9174c2	2024-09-14 16:08:27	64	79	\\x65386537356436326239336533306232346238626639373861313235343461323762333234656664373562323534363131333536353265633736643038386562	https://state.tx.us/eleifend/donec/ut/dolor.xml?quam=tempor&a=turpis&odio=nec&in=euismod&hac=scelerisque&habitasse=quam&platea=turpis&dictumst=adipiscing&maecenas=lorem&ut=vitae&massa=mattis&quis=nibh&augue=ligula&luctus=nec&tincidunt=sem&nulla=duis&mollis=aliquam&molestie=convallis&lorem=nunc&quisque=proin&ut=at&erat=turpis&curabitur=a&gravida=pede&nisi=posuere&at=nonummy&nibh=integer&in=non&hac=velit&habitasse=donec&platea=diam&dictumst=neque&aliquam=vestibulum&augue=eget&quam=vulputate&sollicitudin=ut&vitae=ultrices&consectetuer=vel&eget=augue&rutrum=vestibulum&at=ante&lorem=ipsum&integer=primis&tincidunt=in&ante=faucibus&vel=orci&ipsum=luctus&praesent=et&blandit=ultrices	t	74652
b0313dd5-9ba5-4cca-84d9-85a4ad0158c6	2024-03-14 16:12:35	69	94	\\x37656434336665316537306438386635366634633439323464646139363136343663353639323837333033383832393032656436623661353766656465663434	https://g.co/turpis.js?quis=metus&lectus=aenean&suspendisse=fermentum&potenti=donec&in=ut&eleifend=mauris&quam=eget&a=massa&odio=tempor&in=convallis&hac=nulla&habitasse=neque&platea=libero&dictumst=convallis&maecenas=eget&ut=eleifend&massa=luctus&quis=ultricies&augue=eu&luctus=nibh&tincidunt=quisque&nulla=id&mollis=justo&molestie=sit&lorem=amet&quisque=sapien&ut=dignissim&erat=vestibulum&curabitur=vestibulum&gravida=ante&nisi=ipsum&at=primis&nibh=in&in=faucibus&hac=orci&habitasse=luctus&platea=et&dictumst=ultrices&aliquam=posuere&augue=cubilia&quam=curae&sollicitudin=nulla&vitae=dapibus&consectetuer=dolor&eget=vel&rutrum=est&at=donec&lorem=odio&integer=justo&tincidunt=sollicitudin&ante=ut&vel=suscipit&ipsum=a&praesent=feugiat&blandit=et&lacinia=eros&erat=vestibulum&vestibulum=ac&sed=est	f	61253
3519f342-fe6b-405d-a513-86b37c884450	2024-01-11 20:35:47	11	22	\\x32393561316334333639393836373134363539653237663236613966653461346233373935326533316639633537303436326461663938613662396130393138	http://usda.gov/et.html?turpis=elementum&eget=ligula&elit=vehicula&sodales=consequat&scelerisque=morbi&mauris=a&sit=ipsum&amet=integer&eros=a&suspendisse=nibh&accumsan=in&tortor=quis&quis=justo&turpis=maecenas&sed=rhoncus&ante=aliquam&vivamus=lacus&tortor=morbi&duis=quis&mattis=tortor&egestas=id&metus=nulla&aenean=ultrices&fermentum=aliquet&donec=maecenas&ut=leo&mauris=odio	f	11019
1989b0bc-4378-4a6e-8535-e81173133f93	2024-07-05 08:58:30	35	89	\\x39623438386531393263376465363236363134616561633264333234656262303665643839653435633434663930343163353638633331616430373830303939	http://zdnet.com/odio/curabitur/convallis/duis/consequat/dui/nec.png?ante=molestie&ipsum=hendrerit&primis=at&in=vulputate&faucibus=vitae&orci=nisl&luctus=aenean&et=lectus&ultrices=pellentesque&posuere=eget&cubilia=nunc&curae=donec&nulla=quis&dapibus=orci&dolor=eget&vel=orci&est=vehicula&donec=condimentum&odio=curabitur&justo=in&sollicitudin=libero&ut=ut&suscipit=massa&a=volutpat&feugiat=convallis&et=morbi&eros=odio&vestibulum=odio&ac=elementum&est=eu&lacinia=interdum&nisi=eu&venenatis=tincidunt&tristique=in&fusce=leo&congue=maecenas&diam=pulvinar&id=lobortis&ornare=est&imperdiet=phasellus&sapien=sit&urna=amet&pretium=erat&nisl=nulla&ut=tempus&volutpat=vivamus&sapien=in&arcu=felis&sed=eu&augue=sapien&aliquam=cursus&erat=vestibulum&volutpat=proin&in=eu&congue=mi&etiam=nulla&justo=ac&etiam=enim&pretium=in&iaculis=tempor&justo=turpis&in=nec&hac=euismod&habitasse=scelerisque&platea=quam&dictumst=turpis&etiam=adipiscing&faucibus=lorem&cursus=vitae&urna=mattis&ut=nibh&tellus=ligula&nulla=nec&ut=sem&erat=duis&id=aliquam&mauris=convallis&vulputate=nunc&elementum=proin	f	47295
76eccf00-d73b-4197-a457-727781dcee4f	2023-11-04 20:17:05	56	20	\\x32376639356636333737313463323066636663343033393538333230623930323332336430323037313761656534303334636235356564343466353137643561	https://census.gov/duis.aspx?in=curae&blandit=duis&ultrices=faucibus&enim=accumsan&lorem=odio&ipsum=curabitur&dolor=convallis&sit=duis&amet=consequat&consectetuer=dui&adipiscing=nec&elit=nisi&proin=volutpat&interdum=eleifend&mauris=donec&non=ut&ligula=dolor&pellentesque=morbi&ultrices=vel&phasellus=lectus&id=in&sapien=quam&in=fringilla&sapien=rhoncus&iaculis=mauris&congue=enim&vivamus=leo&metus=rhoncus&arcu=sed&adipiscing=vestibulum&molestie=sit&hendrerit=amet&at=cursus&vulputate=id&vitae=turpis&nisl=integer&aenean=aliquet&lectus=massa&pellentesque=id&eget=lobortis&nunc=convallis&donec=tortor&quis=risus&orci=dapibus&eget=augue&orci=vel&vehicula=accumsan&condimentum=tellus&curabitur=nisi&in=eu&libero=orci&ut=mauris&massa=lacinia&volutpat=sapien&convallis=quis&morbi=libero&odio=nullam&odio=sit	f	59634
57f85f07-3b26-4caf-9ed1-2092cb1fbd34	2024-06-26 21:37:21	98	38	\\x33633961643063613337613962316265616163656662383261663965393261346136393830326161616566373464643064386533633766386631623962653938	http://ow.ly/nisl/duis.json?venenatis=ut&non=erat&sodales=curabitur&sed=gravida&tincidunt=nisi	t	18639
79979547-c11c-4ca7-9da7-002458c9684b	2024-01-08 09:32:56	58	76	\\x32326636336262353739376565303763303661336133353362656336623830383330646263306565633738376339613062653231393666343064373533343064	https://free.fr/ut.jpg?libero=velit&ut=nec&massa=nisi&volutpat=vulputate&convallis=nonummy&morbi=maecenas&odio=tincidunt&odio=lacus&elementum=at&eu=velit&interdum=vivamus&eu=vel&tincidunt=nulla&in=eget&leo=eros&maecenas=elementum&pulvinar=pellentesque&lobortis=quisque&est=porta&phasellus=volutpat&sit=erat&amet=quisque&erat=erat&nulla=eros&tempus=viverra&vivamus=eget&in=congue&felis=eget&eu=semper&sapien=rutrum&cursus=nulla&vestibulum=nunc&proin=purus&eu=phasellus&mi=in&nulla=felis&ac=donec&enim=semper&in=sapien&tempor=a&turpis=libero&nec=nam&euismod=dui&scelerisque=proin&quam=leo&turpis=odio&adipiscing=porttitor&lorem=id&vitae=consequat&mattis=in&nibh=consequat&ligula=ut&nec=nulla&sem=sed&duis=accumsan&aliquam=felis&convallis=ut&nunc=at&proin=dolor&at=quis&turpis=odio&a=consequat&pede=varius&posuere=integer&nonummy=ac	f	57731
5351c391-372f-46a4-83ce-85aaea7742b7	2023-11-02 07:01:41	88	22	\\x32643733643934633635343565313238366661366437666136623436653861373135346430323535356237323737356231323130653466353531656361333538	http://phpbb.com/lobortis/sapien/sapien/non/mi.jpg?risus=ultricies&praesent=eu&lectus=nibh&vestibulum=quisque&quam=id&sapien=justo&varius=sit&ut=amet&blandit=sapien&non=dignissim&interdum=vestibulum&in=vestibulum&ante=ante&vestibulum=ipsum&ante=primis&ipsum=in&primis=faucibus&in=orci&faucibus=luctus&orci=et&luctus=ultrices&et=posuere&ultrices=cubilia&posuere=curae&cubilia=nulla&curae=dapibus&duis=dolor&faucibus=vel&accumsan=est&odio=donec&curabitur=odio&convallis=justo&duis=sollicitudin&consequat=ut&dui=suscipit&nec=a&nisi=feugiat&volutpat=et&eleifend=eros&donec=vestibulum&ut=ac&dolor=est&morbi=lacinia&vel=nisi&lectus=venenatis&in=tristique&quam=fusce&fringilla=congue&rhoncus=diam&mauris=id&enim=ornare&leo=imperdiet&rhoncus=sapien&sed=urna&vestibulum=pretium&sit=nisl&amet=ut&cursus=volutpat&id=sapien&turpis=arcu&integer=sed&aliquet=augue&massa=aliquam&id=erat&lobortis=volutpat&convallis=in&tortor=congue&risus=etiam&dapibus=justo&augue=etiam&vel=pretium&accumsan=iaculis&tellus=justo&nisi=in&eu=hac&orci=habitasse&mauris=platea&lacinia=dictumst&sapien=etiam&quis=faucibus&libero=cursus	f	93714
4c79c51d-e1a6-4e33-989b-91922db093ec	2024-08-09 05:10:00	28	52	\\x36663732393138666638383137316532353332303235656530343866326439383962333332633238646434333063326237306461636234356132346661303531	http://360.cn/quisque/erat/eros/viverra/eget/congue.png?quisque=ullamcorper&erat=augue&eros=a&viverra=suscipit&eget=nulla&congue=elit&eget=ac&semper=nulla&rutrum=sed&nulla=vel&nunc=enim&purus=sit&phasellus=amet&in=nunc&felis=viverra&donec=dapibus&semper=nulla&sapien=suscipit&a=ligula&libero=in&nam=lacus&dui=curabitur&proin=at&leo=ipsum&odio=ac&porttitor=tellus	t	93854
e37aeab6-1be7-4fc8-94c1-684e258e660e	2024-07-14 01:09:12	25	64	\\x61326564636466646336386361393765353633613432393761626138303835313439663834633332346564663037383832333862653136663032363966636335	https://sciencedirect.com/sapien/cursus.xml?luctus=justo&cum=maecenas&sociis=rhoncus&natoque=aliquam&penatibus=lacus&et=morbi&magnis=quis&dis=tortor&parturient=id&montes=nulla&nascetur=ultrices&ridiculus=aliquet&mus=maecenas&vivamus=leo&vestibulum=odio&sagittis=condimentum&sapien=id&cum=luctus&sociis=nec&natoque=molestie&penatibus=sed&et=justo&magnis=pellentesque&dis=viverra&parturient=pede&montes=ac&nascetur=diam&ridiculus=cras&mus=pellentesque&etiam=volutpat&vel=dui&augue=maecenas&vestibulum=tristique&rutrum=est&rutrum=et&neque=tempus&aenean=semper&auctor=est&gravida=quam&sem=pharetra&praesent=magna&id=ac&massa=consequat&id=metus&nisl=sapien&venenatis=ut&lacinia=nunc&aenean=vestibulum&sit=ante&amet=ipsum&justo=primis&morbi=in&ut=faucibus&odio=orci&cras=luctus&mi=et&pede=ultrices&malesuada=posuere&in=cubilia&imperdiet=curae&et=mauris&commodo=viverra&vulputate=diam&justo=vitae&in=quam&blandit=suspendisse&ultrices=potenti&enim=nullam&lorem=porttitor&ipsum=lacus	t	28231
36c1a79a-a65e-4474-8ffa-8f8e0355b99d	2024-10-16 03:21:56	67	92	\\x32663932363563353737366238363637333065303631383061303565666661666333346461303861643962356130333139636561343037393830623964613230	https://google.co.jp/turpis/sed/ante/vivamus/tortor.jsp?integer=in&ac=felis&leo=donec&pellentesque=semper&ultrices=sapien&mattis=a&odio=libero&donec=nam&vitae=dui&nisi=proin&nam=leo&ultrices=odio&libero=porttitor&non=id&mattis=consequat&pulvinar=in&nulla=consequat&pede=ut&ullamcorper=nulla&augue=sed&a=accumsan&suscipit=felis&nulla=ut&elit=at&ac=dolor&nulla=quis&sed=odio&vel=consequat&enim=varius&sit=integer&amet=ac&nunc=leo&viverra=pellentesque&dapibus=ultrices&nulla=mattis&suscipit=odio&ligula=donec&in=vitae&lacus=nisi&curabitur=nam&at=ultrices&ipsum=libero&ac=non&tellus=mattis&semper=pulvinar&interdum=nulla&mauris=pede&ullamcorper=ullamcorper&purus=augue&sit=a&amet=suscipit&nulla=nulla&quisque=elit&arcu=ac&libero=nulla&rutrum=sed	f	79505
388853e4-b20d-4200-9ced-f26e7fe20f32	2024-07-05 23:49:47	65	6	\\x31326466323336663032346666356131663539343532353638626466353932353734326436616161353763643530363932323132393933363831623661656439	http://myspace.com/justo/etiam/pretium.xml?suspendisse=erat&potenti=eros&in=viverra&eleifend=eget&quam=congue&a=eget&odio=semper&in=rutrum&hac=nulla&habitasse=nunc&platea=purus&dictumst=phasellus&maecenas=in&ut=felis&massa=donec&quis=semper&augue=sapien&luctus=a&tincidunt=libero&nulla=nam&mollis=dui&molestie=proin&lorem=leo&quisque=odio&ut=porttitor&erat=id&curabitur=consequat&gravida=in&nisi=consequat&at=ut&nibh=nulla	f	1664
ad2f05a2-99df-499b-9b37-77fd9c74a1e3	2023-11-27 06:21:10	60	69	\\x32353664373336383334393565623338373338386238383639323136653538656635353062646534333232353534396463653061613839323131316332636663	https://mac.com/faucibus/cursus/urna/ut/tellus/nulla/ut.html?adipiscing=dolor&molestie=sit&hendrerit=amet&at=consectetuer&vulputate=adipiscing&vitae=elit&nisl=proin&aenean=interdum&lectus=mauris&pellentesque=non&eget=ligula&nunc=pellentesque&donec=ultrices&quis=phasellus&orci=id&eget=sapien&orci=in&vehicula=sapien&condimentum=iaculis&curabitur=congue&in=vivamus&libero=metus&ut=arcu&massa=adipiscing&volutpat=molestie&convallis=hendrerit&morbi=at&odio=vulputate&odio=vitae&elementum=nisl&eu=aenean&interdum=lectus&eu=pellentesque&tincidunt=eget&in=nunc&leo=donec&maecenas=quis&pulvinar=orci	t	76822
05cf44ed-c3fb-412f-8d9a-06528f1c6b90	2023-11-07 22:05:28	45	7	\\x32363635316434343337643966333833373461323938623630366565386363666638653266393063613537363061616239366538653563323438663365383334	https://mapy.cz/condimentum/curabitur/in/libero/ut/massa/volutpat.js?tristique=quam&in=sapien&tempus=varius&sit=ut&amet=blandit&sem=non&fusce=interdum&consequat=in&nulla=ante&nisl=vestibulum&nunc=ante&nisl=ipsum&duis=primis&bibendum=in&felis=faucibus&sed=orci&interdum=luctus&venenatis=et&turpis=ultrices&enim=posuere&blandit=cubilia&mi=curae&in=duis&porttitor=faucibus&pede=accumsan&justo=odio&eu=curabitur&massa=convallis&donec=duis&dapibus=consequat&duis=dui&at=nec&velit=nisi&eu=volutpat&est=eleifend&congue=donec&elementum=ut&in=dolor&hac=morbi&habitasse=vel&platea=lectus&dictumst=in&morbi=quam&vestibulum=fringilla&velit=rhoncus&id=mauris&pretium=enim&iaculis=leo&diam=rhoncus&erat=sed&fermentum=vestibulum&justo=sit&nec=amet&condimentum=cursus&neque=id&sapien=turpis&placerat=integer&ante=aliquet&nulla=massa&justo=id&aliquam=lobortis&quis=convallis&turpis=tortor&eget=risus&elit=dapibus&sodales=augue&scelerisque=vel&mauris=accumsan&sit=tellus&amet=nisi&eros=eu&suspendisse=orci&accumsan=mauris&tortor=lacinia&quis=sapien&turpis=quis&sed=libero&ante=nullam&vivamus=sit&tortor=amet&duis=turpis&mattis=elementum&egestas=ligula&metus=vehicula&aenean=consequat&fermentum=morbi&donec=a&ut=ipsum&mauris=integer&eget=a&massa=nibh&tempor=in&convallis=quis&nulla=justo&neque=maecenas&libero=rhoncus	f	56053
209f41e4-52eb-4829-94d2-c158e91cba6b	2024-08-11 04:24:34	1	59	\\x31626230333731326563336530323536653762316335386633333630616334366239333336343931366261613665363230373935386362653533663039376161	http://eepurl.com/integer.json?pede=id&malesuada=mauris&in=vulputate&imperdiet=elementum&et=nullam&commodo=varius&vulputate=nulla&justo=facilisi&in=cras&blandit=non&ultrices=velit&enim=nec&lorem=nisi&ipsum=vulputate&dolor=nonummy&sit=maecenas&amet=tincidunt&consectetuer=lacus&adipiscing=at&elit=velit&proin=vivamus&interdum=vel&mauris=nulla&non=eget&ligula=eros&pellentesque=elementum&ultrices=pellentesque&phasellus=quisque&id=porta&sapien=volutpat&in=erat&sapien=quisque&iaculis=erat&congue=eros&vivamus=viverra&metus=eget&arcu=congue&adipiscing=eget&molestie=semper&hendrerit=rutrum&at=nulla&vulputate=nunc&vitae=purus&nisl=phasellus&aenean=in&lectus=felis&pellentesque=donec&eget=semper&nunc=sapien&donec=a&quis=libero&orci=nam	t	32173
f786fddd-690f-498d-bee8-f9f6cc63be35	2024-05-24 09:32:59	51	69	\\x30386333643036653135653565306631346530323762643163633763666564323635373139646263303163363462663565393430383863393161313239386439	https://yale.edu/elementum/pellentesque/quisque/porta/volutpat/erat/quisque.xml?neque=eu&vestibulum=massa&eget=donec&vulputate=dapibus&ut=duis&ultrices=at&vel=velit&augue=eu&vestibulum=est&ante=congue&ipsum=elementum&primis=in&in=hac&faucibus=habitasse&orci=platea&luctus=dictumst&et=morbi&ultrices=vestibulum&posuere=velit&cubilia=id&curae=pretium&donec=iaculis&pharetra=diam&magna=erat&vestibulum=fermentum&aliquet=justo&ultrices=nec&erat=condimentum&tortor=neque&sollicitudin=sapien&mi=placerat&sit=ante&amet=nulla&lobortis=justo&sapien=aliquam&sapien=quis&non=turpis&mi=eget&integer=elit&ac=sodales&neque=scelerisque&duis=mauris&bibendum=sit	f	77920
105ba1d4-6a52-4472-a3d9-d7f8787dcc20	2024-09-22 06:27:01	99	15	\\x65653262383638643439303739616464616439323738643262303262356233653035643664653066396263316366363539303938333064373637616130383365	http://google.co.jp/in/quam/fringilla.xml?nulla=lobortis&ultrices=ligula&aliquet=sit&maecenas=amet&leo=eleifend&odio=pede&condimentum=libero&id=quis&luctus=orci&nec=nullam&molestie=molestie&sed=nibh&justo=in&pellentesque=lectus&viverra=pellentesque&pede=at&ac=nulla&diam=suspendisse&cras=potenti&pellentesque=cras&volutpat=in&dui=purus&maecenas=eu&tristique=magna&est=vulputate	f	41819
2ccc2b6e-e152-4eb5-b58f-8b632aaca1dd	2024-09-21 18:32:05	75	49	\\x66373866343732366239633361633135653834336332366337373835353430313335353238653339383538303334373338336561376538306663373339313537	https://unicef.org/proin/interdum/mauris/non.aspx?vitae=donec&mattis=quis&nibh=orci&ligula=eget&nec=orci&sem=vehicula&duis=condimentum&aliquam=curabitur&convallis=in&nunc=libero&proin=ut&at=massa&turpis=volutpat&a=convallis&pede=morbi&posuere=odio&nonummy=odio&integer=elementum&non=eu&velit=interdum&donec=eu&diam=tincidunt&neque=in&vestibulum=leo&eget=maecenas&vulputate=pulvinar&ut=lobortis&ultrices=est&vel=phasellus&augue=sit&vestibulum=amet&ante=erat&ipsum=nulla&primis=tempus&in=vivamus&faucibus=in&orci=felis&luctus=eu&et=sapien&ultrices=cursus&posuere=vestibulum&cubilia=proin&curae=eu&donec=mi&pharetra=nulla&magna=ac&vestibulum=enim&aliquet=in&ultrices=tempor&erat=turpis&tortor=nec&sollicitudin=euismod&mi=scelerisque&sit=quam&amet=turpis&lobortis=adipiscing&sapien=lorem&sapien=vitae&non=mattis&mi=nibh&integer=ligula&ac=nec&neque=sem&duis=duis&bibendum=aliquam&morbi=convallis&non=nunc&quam=proin&nec=at&dui=turpis&luctus=a&rutrum=pede&nulla=posuere&tellus=nonummy&in=integer&sagittis=non&dui=velit&vel=donec&nisl=diam&duis=neque&ac=vestibulum&nibh=eget&fusce=vulputate&lacus=ut&purus=ultrices&aliquet=vel&at=augue&feugiat=vestibulum&non=ante&pretium=ipsum&quis=primis&lectus=in&suspendisse=faucibus&potenti=orci&in=luctus&eleifend=et&quam=ultrices&a=posuere	t	42614
664fb721-7d28-445d-8578-1fcdb420a221	2024-08-09 02:35:28	53	90	\\x66356162363639623939323331653739363930323231313261313938663466303438663132636664333138383632363138653065363866306439353438333733	https://constantcontact.com/scelerisque.html?maecenas=varius&rhoncus=nulla&aliquam=facilisi&lacus=cras&morbi=non&quis=velit&tortor=nec&id=nisi&nulla=vulputate&ultrices=nonummy&aliquet=maecenas&maecenas=tincidunt&leo=lacus&odio=at&condimentum=velit&id=vivamus&luctus=vel&nec=nulla&molestie=eget&sed=eros&justo=elementum&pellentesque=pellentesque&viverra=quisque&pede=porta&ac=volutpat&diam=erat&cras=quisque&pellentesque=erat&volutpat=eros&dui=viverra&maecenas=eget&tristique=congue&est=eget&et=semper&tempus=rutrum&semper=nulla&est=nunc&quam=purus&pharetra=phasellus&magna=in&ac=felis&consequat=donec&metus=semper&sapien=sapien&ut=a&nunc=libero&vestibulum=nam&ante=dui&ipsum=proin&primis=leo&in=odio&faucibus=porttitor&orci=id&luctus=consequat&et=in&ultrices=consequat&posuere=ut&cubilia=nulla&curae=sed&mauris=accumsan&viverra=felis&diam=ut&vitae=at&quam=dolor&suspendisse=quis&potenti=odio&nullam=consequat&porttitor=varius&lacus=integer&at=ac&turpis=leo&donec=pellentesque&posuere=ultrices&metus=mattis&vitae=odio&ipsum=donec&aliquam=vitae&non=nisi&mauris=nam	f	59716
4ef11c56-6d5e-4549-ac12-68bf6d4e0e3c	2024-03-06 20:22:00	68	78	\\x61623964346634623563353636343237613264373430616133643536653731353938336433666338353835653932333462376362346434326664373430393063	https://slate.com/ligula/vehicula/consequat/morbi.json?sem=in&duis=libero&aliquam=ut&convallis=massa&nunc=volutpat&proin=convallis&at=morbi&turpis=odio&a=odio&pede=elementum&posuere=eu&nonummy=interdum&integer=eu&non=tincidunt&velit=in&donec=leo&diam=maecenas&neque=pulvinar&vestibulum=lobortis&eget=est&vulputate=phasellus&ut=sit&ultrices=amet&vel=erat&augue=nulla&vestibulum=tempus&ante=vivamus&ipsum=in&primis=felis&in=eu&faucibus=sapien&orci=cursus&luctus=vestibulum&et=proin&ultrices=eu&posuere=mi&cubilia=nulla&curae=ac&donec=enim&pharetra=in&magna=tempor&vestibulum=turpis&aliquet=nec&ultrices=euismod	f	98680
152e7e81-3c4b-440b-b507-e46da6c4ab0e	2024-07-18 08:44:07	100	77	\\x32313766393136323230386465326365323039643038303861643733623163653738666531663862643835323062373435663637376162623630623635633737	https://mail.ru/augue.xml?aliquam=vulputate&quis=vitae&turpis=nisl&eget=aenean&elit=lectus&sodales=pellentesque&scelerisque=eget&mauris=nunc&sit=donec&amet=quis&eros=orci&suspendisse=eget&accumsan=orci&tortor=vehicula&quis=condimentum&turpis=curabitur&sed=in&ante=libero&vivamus=ut&tortor=massa&duis=volutpat&mattis=convallis&egestas=morbi&metus=odio&aenean=odio&fermentum=elementum&donec=eu&ut=interdum&mauris=eu&eget=tincidunt&massa=in&tempor=leo&convallis=maecenas&nulla=pulvinar	f	75605
c69d5f1d-a59e-41ca-b74f-8e93b9ec41a2	2024-04-18 16:40:17	17	25	\\x35333938313564343261353832323466346235333361633262643731616664373666643266386362343235316337303862333434386238363134653066383566	http://examiner.com/sed/nisl/nunc/rhoncus/dui/vel/sem.xml?ut=duis&massa=ac&quis=nibh&augue=fusce&luctus=lacus&tincidunt=purus&nulla=aliquet&mollis=at	t	34804
2064a42d-f721-4aef-b6f0-a2bab04d2c3c	2024-09-25 02:25:21	12	2	\\x37653233386330653634613332366233623764346335653532613363653437623332353535643261363130383832336337663439346363376433333635366666	http://facebook.com/ornare/imperdiet/sapien.jsp?nam=sed&nulla=lacus&integer=morbi&pede=sem&justo=mauris&lacinia=laoreet&eget=ut&tincidunt=rhoncus&eget=aliquet&tempus=pulvinar&vel=sed&pede=nisl&morbi=nunc&porttitor=rhoncus&lorem=dui&id=vel&ligula=sem&suspendisse=sed&ornare=sagittis&consequat=nam&lectus=congue&in=risus&est=semper&risus=porta&auctor=volutpat&sed=quam&tristique=pede&in=lobortis&tempus=ligula&sit=sit&amet=amet&sem=eleifend&fusce=pede&consequat=libero&nulla=quis&nisl=orci&nunc=nullam&nisl=molestie&duis=nibh&bibendum=in&felis=lectus&sed=pellentesque&interdum=at&venenatis=nulla&turpis=suspendisse&enim=potenti&blandit=cras&mi=in&in=purus&porttitor=eu&pede=magna&justo=vulputate&eu=luctus&massa=cum&donec=sociis&dapibus=natoque&duis=penatibus&at=et&velit=magnis&eu=dis&est=parturient&congue=montes&elementum=nascetur&in=ridiculus&hac=mus&habitasse=vivamus&platea=vestibulum&dictumst=sagittis&morbi=sapien&vestibulum=cum&velit=sociis	t	28147
60bbcf26-410d-4789-a7a6-6ac0a4dee73a	2024-08-14 08:02:34	45	68	\\x61656234333137663363396432366664313035623833623563396136313264353537333661386162323236313935316566306630326661396332656133666561	http://people.com.cn/sociis/natoque/penatibus/et/magnis/dis.jsp?habitasse=amet	f	54992
14f487d9-83d7-4ff7-887a-cde148b35cab	2024-08-03 15:25:33	4	55	\\x31626665316433393135636133393736633064396165343933663662333631326439346462313239373165313861383733653164616534313139396336333461	http://angelfire.com/tincidunt/in.js?duis=varius&aliquam=ut&convallis=blandit&nunc=non&proin=interdum&at=in&turpis=ante&a=vestibulum&pede=ante&posuere=ipsum&nonummy=primis&integer=in&non=faucibus&velit=orci&donec=luctus&diam=et&neque=ultrices&vestibulum=posuere&eget=cubilia&vulputate=curae&ut=duis&ultrices=faucibus&vel=accumsan&augue=odio&vestibulum=curabitur&ante=convallis&ipsum=duis&primis=consequat&in=dui&faucibus=nec	f	48214
d27970ba-5356-4532-9cdf-ab2157ff671b	2023-11-28 07:34:17	82	64	\\x32653964613534613338363836616439643639616432666365333438333564663433323832376537306666383338623838646564363135336133653563333061	https://geocities.jp/dolor/sit/amet/consectetuer.js?et=porttitor&ultrices=lacus&posuere=at&cubilia=turpis&curae=donec&donec=posuere&pharetra=metus&magna=vitae&vestibulum=ipsum&aliquet=aliquam&ultrices=non&erat=mauris&tortor=morbi&sollicitudin=non&mi=lectus&sit=aliquam&amet=sit&lobortis=amet&sapien=diam&sapien=in&non=magna&mi=bibendum&integer=imperdiet&ac=nullam&neque=orci&duis=pede&bibendum=venenatis&morbi=non&non=sodales&quam=sed&nec=tincidunt&dui=eu&luctus=felis&rutrum=fusce&nulla=posuere&tellus=felis&in=sed&sagittis=lacus&dui=morbi&vel=sem&nisl=mauris&duis=laoreet&ac=ut&nibh=rhoncus&fusce=aliquet&lacus=pulvinar&purus=sed&aliquet=nisl&at=nunc&feugiat=rhoncus&non=dui&pretium=vel&quis=sem&lectus=sed&suspendisse=sagittis&potenti=nam&in=congue&eleifend=risus&quam=semper&a=porta&odio=volutpat&in=quam&hac=pede&habitasse=lobortis&platea=ligula&dictumst=sit&maecenas=amet&ut=eleifend&massa=pede&quis=libero&augue=quis&luctus=orci&tincidunt=nullam&nulla=molestie&mollis=nibh&molestie=in&lorem=lectus&quisque=pellentesque&ut=at	f	91639
7111b66b-452b-4ea3-94de-d4b9df8afc12	2024-06-20 01:14:46	44	87	\\x37396637363831663162336134666262363437373733366235626536653663653563333562393530393337346637613836623537386132363231353462636666	https://ow.ly/nisl/venenatis/lacinia.xml?at=nullam&ipsum=molestie&ac=nibh&tellus=in&semper=lectus&interdum=pellentesque&mauris=at&ullamcorper=nulla&purus=suspendisse&sit=potenti&amet=cras&nulla=in&quisque=purus&arcu=eu&libero=magna&rutrum=vulputate&ac=luctus&lobortis=cum&vel=sociis&dapibus=natoque&at=penatibus&diam=et&nam=magnis&tristique=dis&tortor=parturient&eu=montes	t	4893
dec1f80b-9bd4-4570-8f22-df2cf57c039e	2024-03-25 21:30:07	22	26	\\x35366165626635346465633661343035623966653937353835343732353962363336303134623737346133383531393564326563306334613933353636613632	https://va.gov/odio/cras/mi.png?pede=etiam&justo=vel&eu=augue&massa=vestibulum&donec=rutrum&dapibus=rutrum&duis=neque&at=aenean&velit=auctor&eu=gravida&est=sem&congue=praesent&elementum=id&in=massa&hac=id&habitasse=nisl&platea=venenatis&dictumst=lacinia&morbi=aenean&vestibulum=sit&velit=amet&id=justo&pretium=morbi&iaculis=ut&diam=odio&erat=cras&fermentum=mi&justo=pede&nec=malesuada&condimentum=in&neque=imperdiet&sapien=et&placerat=commodo&ante=vulputate&nulla=justo&justo=in&aliquam=blandit&quis=ultrices&turpis=enim&eget=lorem&elit=ipsum&sodales=dolor&scelerisque=sit&mauris=amet&sit=consectetuer&amet=adipiscing&eros=elit&suspendisse=proin&accumsan=interdum	f	67310
810fa726-a209-42fd-b90f-34a850e6b77e	2024-01-22 11:53:07	75	94	\\x36396466616537343337333435653337636463333432653534633662663731653531306161353563646432376464343039653766623437393632633437343766	https://auda.org.au/vestibulum/ante/ipsum/primis/in/faucibus.aspx?lobortis=in&ligula=faucibus&sit=orci&amet=luctus&eleifend=et&pede=ultrices&libero=posuere&quis=cubilia&orci=curae&nullam=nulla&molestie=dapibus&nibh=dolor&in=vel&lectus=est&pellentesque=donec&at=odio&nulla=justo&suspendisse=sollicitudin&potenti=ut&cras=suscipit&in=a&purus=feugiat&eu=et&magna=eros&vulputate=vestibulum&luctus=ac&cum=est&sociis=lacinia&natoque=nisi&penatibus=venenatis&et=tristique&magnis=fusce&dis=congue&parturient=diam&montes=id&nascetur=ornare&ridiculus=imperdiet&mus=sapien&vivamus=urna&vestibulum=pretium&sagittis=nisl&sapien=ut&cum=volutpat&sociis=sapien&natoque=arcu&penatibus=sed&et=augue&magnis=aliquam&dis=erat&parturient=volutpat&montes=in&nascetur=congue&ridiculus=etiam&mus=justo&etiam=etiam&vel=pretium&augue=iaculis&vestibulum=justo&rutrum=in&rutrum=hac&neque=habitasse&aenean=platea&auctor=dictumst&gravida=etiam	t	12576
48ad2dc0-ec6e-4a32-b418-6f750576e8a8	2024-01-31 08:53:54	65	8	\\x64653636343139656534353766306261356265643632323334643462653064313466386564636438313833666565613065303934336432333039343937336430	http://purevolume.com/odio.aspx?posuere=sapien&cubilia=sapien&curae=non&mauris=mi&viverra=integer&diam=ac&vitae=neque&quam=duis&suspendisse=bibendum&potenti=morbi&nullam=non&porttitor=quam&lacus=nec&at=dui&turpis=luctus&donec=rutrum&posuere=nulla&metus=tellus&vitae=in&ipsum=sagittis&aliquam=dui&non=vel&mauris=nisl&morbi=duis&non=ac&lectus=nibh&aliquam=fusce&sit=lacus&amet=purus&diam=aliquet&in=at&magna=feugiat&bibendum=non&imperdiet=pretium&nullam=quis&orci=lectus&pede=suspendisse&venenatis=potenti&non=in&sodales=eleifend&sed=quam&tincidunt=a&eu=odio&felis=in&fusce=hac&posuere=habitasse&felis=platea&sed=dictumst&lacus=maecenas&morbi=ut&sem=massa&mauris=quis&laoreet=augue&ut=luctus&rhoncus=tincidunt&aliquet=nulla&pulvinar=mollis&sed=molestie&nisl=lorem&nunc=quisque&rhoncus=ut&dui=erat&vel=curabitur&sem=gravida&sed=nisi&sagittis=at&nam=nibh&congue=in&risus=hac&semper=habitasse&porta=platea&volutpat=dictumst&quam=aliquam&pede=augue&lobortis=quam&ligula=sollicitudin&sit=vitae&amet=consectetuer&eleifend=eget&pede=rutrum&libero=at&quis=lorem	f	58315
9d88c2b5-fadd-4242-ad5f-d7996683a487	2024-07-03 12:47:38	46	38	\\x38653535363335323731323536313961306334316339646562346633623933313237323833353164373765306364316166396337336561623864633137306438	https://clickbank.net/lacinia/erat/vestibulum/sed/magna.aspx?habitasse=sollicitudin&platea=mi&dictumst=sit&maecenas=amet	f	25269
baa71d99-dee1-4481-9c5a-53d8c6d037cc	2024-11-04 21:13:44.040854	0	0	\\xccf0c5ea7b9168efcb47fff8b133b609bbf6e963cce552439d23a0537b9d0d14	http://jakiśtam.ułerel	t	1
052caf5c-4979-41e6-aa45-32fb141b8707	2024-11-04 23:07:44.707471	0	0	\\x902e6654e847c50bc3eecdb24cf4e05b9faf5a214590a74f0fa011bc1c52fa40	http://jakiśtam.ułerelek	t	1
ec339108-81b4-42b8-b938-7984bfdf60e4	2024-11-07 21:06:48.00504	0	0	\\xf94935df03eab9734027cbaffe19d367c24c2b1a80dab07d1379bda8ad65f614	http://jakiśtam.ułerelek.kochany	t	1
eeaf8b8e-921d-4f53-8a5a-8ef0da867ceb	2024-11-07 21:07:52.249524	0	0	\\xf97598f5809ff6e71f1527b05622e2a3ee95b7bcee06b1d52bbfb007f2c825b7	http://jakiśtam.ułerelek.kochanyy	t	1
8ea0f711-62a0-4ca1-8e24-7249bed7c90a	2024-11-07 21:16:31.455601	0	0	\\xa15f7c4ba37af7a5ee932019004fa787eb0d08dcad960a12b82d9c1e4c92cdd9	http://jakiśtam.ułerelek.kochanyjyd	t	1
\.


--
-- Data for Name: share; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.share (resource_id, title, description, uploader_id, category) FROM stdin;
3b85e730-fa0d-4f46-ab5b-9aeeb85ea27d	Silent Hill: Revelation 3D	Family history of consanguinity	5724b424-4956-4870-b54e-74d16c87c1be	ebook
5a441f82-f6b3-4412-96bc-6eac13bb4442	Leopard Man, The	Milt op w explosn of sea-based artlry shell, milt, subs	43329789-04f4-4826-90ad-bcc26b7159a3	music
b5b468c3-d129-4715-b94a-1bc98368fe5a	Suzhou River (Suzhou he)	Oth nondisp fx of base of first MC bone, left hand, sequela	4d0df9d5-a773-43f5-8077-cb08bf62839a	music
649539c3-6c06-42cd-b2cb-099f5fa3581b	Sons of Perdition	Puncture wound without foreign body of penis, init encntr	af5bfaa0-02b9-4a48-b274-6c299c08aacf	game
068cde22-250b-4310-8298-2f07a2f28e58	House of the Devil, The	Poisn by androgens and anabolic congeners, assault, sequela	a1a4a096-126c-43c9-bf03-7b21e9a946b9	ebook
8d9c11e6-678e-41f8-b4bb-5e61bf917c03	In Harm's Way	Glaucoma secondary to eye inflammation, bilateral	13f2a810-c939-4f2f-84fc-b9ff2f55d869	ebook
4c4cd997-bc95-411a-b536-0d80bbb32276	My Night At Maud's (Ma Nuit Chez Maud)	Laceration w/o fb of unsp external genital organs, male	a9f0715f-ef43-43d4-b581-f7e684d53ca6	film
2731312a-5a85-48bd-88cc-613e00777a74	Kid, The	Unsp fracture of fourth metacarpal bone, right hand, sequela	129a86cf-4c77-41b8-b4cd-202a027293f6	film
9f7e5bfc-afc8-469b-9e1d-36511ec47bf2	Cyrano de Bergerac	Unsp focal TBI w LOC of 1-5 hrs 59 min, subs	2eec273d-a233-4fb2-a2ac-78921c2b9f8a	game
86a74d25-4761-478c-87b4-888b9cbc0707	The Woman on Pier 13	Unspecified astigmatism, right eye	c3684e50-5196-4894-a344-6330bc730a1c	music
72601402-45fd-4af9-a779-a5bf788c7427	Crime at the Chinese Restaurant	Chronic gout due to renal impairment, ankle and foot	98a3f0f1-b360-42e3-96e4-de3dbe21116c	music
6aa55a1d-a703-4853-950b-331925635629	Late Quartet, A	Stupor	9da03ce7-da6f-4baa-aebb-5a5f297edd92	music
fac7e88a-d9ca-474e-a165-a490faa20515	Kronos	Unsp fracture of T5-T6 vertebra, init for clos fx	4afcb6e9-d55a-498e-aa0d-212bd81c772c	ebook
e7217078-b339-4d3e-b469-f161c73fc081	Flight of the Living Dead	Unspecified injury of unspecified tibial artery, right leg	a24edb22-17bd-4ed5-aa4d-bab50c8e282f	music
c7a5009c-2ae5-44c5-afb5-bf64c46fe26c	Apartment, The (Appartement, L')	Drown due to acc on board wtrcrft, w/o accident to wtrcrft	1d3ffe92-4b8a-441e-93de-b591662f6c55	film
258dc54d-1b37-4100-84ce-b73b82a9a5f8	American Ninja 3: Blood Hunt	Interstitial myositis, unspecified ankle and foot	d1e124a8-f952-41cb-9976-142750879da2	film
b87992d0-07e8-4722-a46c-0c485531769a	Haunted World of El Superbeasto, The	Laceration w foreign body of left thumb with damage to nail	d2d5543e-314b-40cc-85f9-f0aa9c09f8c9	audiobook
de2adefd-7799-4a41-b0b5-443c11fa046e	Beautiful Country, The	Displ seg fx shaft of l tibia, 7thN	75e8c225-2e80-4a08-8fc5-bdaa7e88464d	ebook
0ae94b84-f390-4195-82c9-44e558a76099	Super Fuzz (a.k.a. Super Snooper) (Poliziotto superpiù)	Pathological fracture in other disease, left radius	d1fbb1f1-6cd0-44ad-b521-10e9bf5b8c97	game
6b11809f-c22c-412a-87d1-ed23f3f7ba56	Don Jon	Unspecified adult maltreatment, confirmed, initial encounter	e021830b-050f-4871-b1d0-12f9be3912a9	music
9f527479-34d3-423c-875b-a20c88bab7f1	Primal Fear	Injury of other nerves at forearm level, right arm	b1bb46bf-afcb-4dd7-b365-0caee244f733	film
5a3dc10f-a2e3-4363-bcad-e65723178e98	Seduction of Joe Tynan, The	Oth Rh incompat reaction due to tranfs of bld/bld prod, subs	c8d69cb9-fc66-48d3-919a-c029a8d228c0	music
cc827187-e665-459e-bd53-38cab8be5843	Red Squirrel, The (Ardilla roja, La)	Hodgkin lymphoma	664c6d57-faa9-43c3-95cc-1e7c23715b97	game
2b4c59a1-96b7-4eee-a47d-3d69d8cf8fd9	Duo (Pas de deux)	Poisoning by penicillins, undetermined, initial encounter	1bd4b85a-c677-49b0-99d2-8df21e1453c9	music
f5c6f0f2-36ba-4217-8b47-07e79ccc357a	Angel Named Billy, An	Other specified injury of thoracic aorta	112fdaa6-0ae1-4aea-9c18-60315bcdcd5e	ebook
22fb047a-a258-4976-9d59-26c0e5e3432a	Look Who's Talking Too	Malignant neoplasm of fundus of stomach	42a1e621-fc79-48d2-9977-d59a538fcde5	ebook
cb7b5a74-07c7-4102-8c1f-01578e5bd65e	White Oleander	Other physeal fracture of left metatarsal, 7thB	2ba927ab-c5e4-401f-82c0-f566f6df8f8e	film
abed90de-e6e3-41bb-8fec-d87ae1f22c7b	I Am You (In Her Skin)	Combined forms of infantile and juvenile cataract, left eye	12fb141a-0cf3-4005-ad57-3ca25df6bfd4	audiobook
16866ac4-7745-4e27-a72c-70c9031e58cb	Midnight (Primeiro Dia, O)	Encounter for contraceptive management, unspecified	97f91c15-b90e-4570-ac5a-32a701d0765b	ebook
8831ded5-b91b-44f6-970b-f20d77c9d95b	180° South (180 Degrees South) (180° South: Conquerors of the Useless)	Toxic effect of contact w oth venom animals, acc, sequela	f211d427-a604-4773-add5-06b1e21342bb	music
aec3cb1f-f48d-4f5b-8c04-f885bcacff4a	Kill the Messenger	Diab due to undrl cond w unsp diab rtnop w/o macular edema	e96a7525-52f7-4dea-8d5c-dc9a60e8e167	game
86736cd2-f038-4b25-b2ee-0ca150d2f4b4	Victor Sjöström: Ett porträtt	Other specified strabismus	8ed51a79-e1c7-495a-8819-d6a8a77ab630	music
19678a34-e91d-4103-b576-9474d67ea982	Star Wars: Episode IV - A New Hope	Motion sickness	4650a8bd-672a-4c6b-9938-b4b292b21e82	film
69ae4d80-9136-460f-b1c5-abf34cdd1cb5	Color Purple, The	Displaced comminuted fx shaft of ulna, right arm, init	75df44b2-6dd7-4eee-a92f-daa430145a11	film
316fde0d-1a48-48e5-adea-76d3e21525bb	Lust, Caution (Se, jie)	Driver of pk-up/van inj in clsn w rail trn/veh in traf, sqla	2206ba91-9b2b-41be-b1cc-4e559c3156f6	film
28279bd7-815d-42c2-a7a6-d999f19f415d	Sweetgrass	Oth private fix-wing aircraft crash injuring occupant, init	cacc35b1-72e6-4fdd-bedd-2e9e81927ee1	game
58c1b148-513c-4319-b08a-385f12befe47	Spin (You Are Here)	Nondisp fx of greater trochanter of l femr, 7thD	9db614e3-d420-4c0c-a70d-6cdad5a9e7d9	ebook
bee827f7-153f-4ea6-8560-c56c457a6dd8	Blackadder's Christmas Carol	Contus/lac/hem brainstem w LOC of unsp duration	b47501d7-614a-416a-bb06-cb0f886981f0	audiobook
9d049c58-229d-4ec8-9cdb-162b0d9f9345	Mansion of Madness, The	Delayed or excess hemor fol ectopic and molar pregnancy	a38d4065-6877-4a6e-8422-d09b7ca3285d	audiobook
3fd3ebf8-5f0e-4f81-82ac-4093890c7db0	Heavy	Traum rupt of volar plate of l idx fngr at MCP/IP jt, init	ecddf7c0-4c18-4fdf-8a18-e8d2b12587e5	film
b4d53818-aefd-4c80-bf50-dae0a23bc41f	Good Morning (Ohayô)	Poisoning by propionic acid derivatives, self-harm, subs	15947aaf-c5d8-47db-a88b-92423d8fceed	film
51c760af-1888-4309-b28c-6c72ba43c5a7	Hitman, The	Poisoning by oth anti-cmn-cold drugs, accidental, sequela	eaa7c2dc-e862-4e78-9040-be988fc6a58f	ebook
d5c9cd40-e0d2-4d29-8cb0-c16ac6e0c4aa	Foolish	Struck by falling object on unsp watercraft, subs encntr	b9debc18-4ebd-4517-a1c8-046d4d787899	ebook
275a4db2-d27e-4a05-9537-424932af3e1c	Royal Scandal, The	Unspecified dislocation of unspecified radial head	c307abf1-b57b-4934-a224-42e46f4e0686	ebook
e7c10140-11fd-4181-b382-ff4101340373	Desert Winds	Unspecified nonsuppurative otitis media, right ear	f453a1d0-2037-499e-8ff6-f6d18a417e42	film
354ed58b-32c5-4aa8-b002-a771bf2a85cb	Secret of the Grain, The (La graine et le mulet)	Pressure ulcer of unspecified part of back, stage 4	829c062f-d408-4d4d-b2d7-3659f4a6578a	music
ce6f1627-5a01-4644-87fa-cac6dca8d158	Batman: Year One	Male infertility	a6350642-884a-47df-82d7-98194b28c170	ebook
7f3fdc55-357c-495f-8f21-ea117815d481	Next Step, The	Bursitis, right hand	0c1aae64-49a4-410d-aae7-8c6845b1fadc	game
44e60dc6-4808-4933-aa49-d0eaf18138e9	Road to Ruin, The	Strain of intrinsic msl/tnd at ankle and foot level	75dec64d-1149-4bd4-b1b5-990078d119cd	ebook
ce73ea30-a02d-47fd-8780-7ea398f64712	Portraits of Women (Naisenkuvia)	Disp fx of less trochanter of l femr, 7thC	9b6c3fff-22ab-4417-9aa2-50b5b5f74c9a	music
4202c24a-f90d-43d5-aa2a-5d38327f5ee7	Mirror Crack'd, The	Nonrheumatic pulmonary valve stenosis with insufficiency	4fb57a62-c8bd-4888-93ba-1e9caff307f6	music
8e028a64-e408-444d-a608-fa2d106fd195	Hackers	Crushing injury of unspecified knee, initial encounter	f828502b-20ac-4811-8dbc-887f555d85ee	music
1ebdf3ce-e494-4c3e-a790-c86bc08e4d67	October	Third degree perineal laceration during delivery, IIIb	310a4dc2-3a54-4d3c-8580-9be94207aea1	audiobook
ac8225ee-d339-43ad-a225-5e62372ef759	Private Fears in Public Places (Coeurs)	Legal intervnt w manhandling, law enforc offl injured	d96bb090-1f7c-4b18-9cc0-7d26ad847d8e	music
43619229-320c-46b5-bbac-a4f471d08dfc	Smokers Only (Vagón Fumador)	War op involving oth explosn and fragmt, civilian, sequela	d28b1b71-6292-4b47-b597-fd617c7063e6	audiobook
cd66b88c-50c7-4ca8-b276-9532b0ebbca2	Lola Montès	Abrasion of right front wall of thorax, subsequent encounter	b362c61d-ca08-4d35-b46b-e47a02a94338	music
b8018acc-9aef-4b73-9a4e-e01d84d9f318	Einstein and Eddington	Fatigue fracture of vertebra, cervical region, init for fx	78c38e0a-446a-42df-898c-8cc6ce4c3e0d	game
d1e5f0c9-6cab-43de-ba2c-bb7d59270c31	Beverly Hills Chihuahua 2	Infect/inflm reaction due to int fix of right humerus	6ca3c632-0823-4163-ae52-b517be42bf03	film
d9071722-e23b-43c2-aa3e-1c8b94bf7366	Road, The	Adverse effect of hormones and synthetic substitutes, subs	9b9a96dc-898a-4b48-8c56-9566b96539bd	audiobook
3690ea3a-a63d-41c8-807f-f223159c9f1f	Star Wars: Episode VI - Return of the Jedi	Glaucoma secondary to eye inflam, unsp eye, severe stage	27a67f4b-5fba-4901-8575-efdab9524bf1	music
6fdc1e11-0f32-4d07-98ba-93573b3f524c	Bedazzled	Infect/inflm reaction due to oth internal prosth dev/grft	3109e086-0d77-411a-9d78-e03a0b2f407a	film
43660367-7831-44f9-903e-4761f20b1a7b	Polisse	Displacement of implanted testicular prosthesis, subs	bc5b7ecf-53a5-4259-a367-cebf950d735d	music
71b8026a-3596-4d44-bc8e-7f9bdf6e4942	Ratatouille	Other GM2 gangliosidosis	5cf95429-8b70-4dc7-b98b-42d981577d08	ebook
9ff3816d-03e2-49cd-98e0-e558f15df6d6	Solaris (Solyaris)	Burn unsp deg mult sites of left lower limb, ex ank/ft, init	6bbefd0e-1d47-4522-a030-0f0908067f9d	game
d21abf58-b53c-4f6b-a0e7-96183b854457	Advanced Style	Salter-Harris Type IV physeal fracture of r calcaneus, 7thB	45c3daee-e335-4cc2-a603-398d4dc82616	game
47a15f21-a98f-494d-9ee4-014f46e06893	Wanted	Underdosing of other synthetic narcotics	07c08cbe-05af-4d07-b948-6397497a7c00	film
e2d28848-9849-4e1d-ba0a-097d7d604859	Trick	Oth tear of lat mensc, current injury, unsp knee, init	e12210c9-f564-4fdf-9a3d-172d23c07a90	music
b630349e-cc0e-47d8-a114-833fc730ffb1	Man with the Movie Camera, The (Chelovek s kino-apparatom)	Leakage of other vascular grafts	d9caa29e-2ff2-4ebe-9cf0-58f32fca4db4	audiobook
075281ab-a70f-4b3f-8869-05bca711fa67	Almost Married	Other injury due to other accident to water-skis, sequela	463d812a-a5bb-484c-bcae-08eef54e8f89	music
a112fd46-a09e-4523-8baf-0bf93e9174c2	Cows (Vacas)	Calcific tendinitis, upper arm	cedc74ca-5ad5-49b5-b51a-a54c852738fe	ebook
b0313dd5-9ba5-4cca-84d9-85a4ad0158c6	Two Escobars, The	Cont preg aft spon abort of one fts or more, third tri, fts5	bf96c44a-90fa-445e-92ac-1ddaec6dee93	ebook
3519f342-fe6b-405d-a513-86b37c884450	Lookout, The	Military operations involving friendly fire, subs encntr	f8f832c8-c1ff-4551-9910-e3b375bec6d7	game
1989b0bc-4378-4a6e-8535-e81173133f93	My Dear Secretary	Nondisp commnt fx shaft of r femr, 7thP	c8e25b96-cb63-4e87-819c-9c07e86c0ca0	game
76eccf00-d73b-4197-a457-727781dcee4f	Lust for Life	Insect bite (nonvenomous), unspecified knee, subs encntr	1873db59-1562-4577-924e-7a7572037b2d	music
57f85f07-3b26-4caf-9ed1-2092cb1fbd34	Belphecor: Curse of the Mummy (Belphégor - Le fantôme du Louvre)	Disp fx of neck of second metacarpal bone, left hand	b747b195-e30f-4abb-a482-826fd60ad271	audiobook
79979547-c11c-4ca7-9da7-002458c9684b	Orphans	Pnctr w/o fb of low back and pelv w penet retroperiton, subs	977028b5-4105-4bea-b1e9-738c6ca1c753	audiobook
5351c391-372f-46a4-83ce-85aaea7742b7	Carbon Nation	Conjunctival granuloma, unspecified	4dbfadad-b431-414c-8b68-8dd663109af1	film
4c79c51d-e1a6-4e33-989b-91922db093ec	Tall Man, The	Major contusion of right kidney, sequela	c6b3e07c-f565-40db-9d50-d136ce9c1104	audiobook
e37aeab6-1be7-4fc8-94c1-684e258e660e	The Day That Lasted 21 Years	Laceration of muscle, fascia and tendon of unsp hip, sequela	0ebbfda8-2b34-4701-b707-74932400204b	audiobook
36c1a79a-a65e-4474-8ffa-8f8e0355b99d	Terrorizers, The (Kong bu fen zi)	Burn of unsp degree of unspecified lower leg, subs encntr	d02f9eb8-d1cb-4532-bdcc-0b83ca79ea78	ebook
388853e4-b20d-4200-9ced-f26e7fe20f32	Reclaim Your Brain (Free Rainer)	Other chronic osteomyelitis, right  humerus	1eaf54aa-2160-473a-b7d6-4e394364738a	ebook
ad2f05a2-99df-499b-9b37-77fd9c74a1e3	That Obscure Object of Desire (Cet obscur objet du désir)	Other dental procedure status	c15deacc-b36c-4540-aac3-e4e91bd82119	audiobook
05cf44ed-c3fb-412f-8d9a-06528f1c6b90	My Brother Tom	Laceration without foreign body of left hand, subs encntr	52c52b56-e36c-4600-ab17-f30b8afe8506	ebook
209f41e4-52eb-4829-94d2-c158e91cba6b	Passion of the Christ, The	Superficial foreign body, unspecified thigh, sequela	8642ffed-4629-480c-a2e5-6d238ed3b2af	audiobook
f786fddd-690f-498d-bee8-f9f6cc63be35	Children of the Corn IV: The Gathering	Disp fx of nk of 4th MC bone, r hand, subs for fx w malunion	1c073ee8-de42-48e9-8408-ec8b7ea6c61d	music
105ba1d4-6a52-4472-a3d9-d7f8787dcc20	Greystoke: The Legend of Tarzan, Lord of the Apes	Lymphocy deplet Hdgkn lymph, nodes of axilla and upper limb	db21ec12-a5da-4e21-9843-e87fc7f94d0a	music
2ccc2b6e-e152-4eb5-b58f-8b632aaca1dd	Rabbit Without Ears (Keinohrhasen)	Injury of facial nerve, left side, sequela	83460de9-1991-4f3f-b14c-e52f8728b533	film
664fb721-7d28-445d-8578-1fcdb420a221	Tukkijoella	Oth enterovirus as the cause of diseases classd elswhr	37c66b8f-ac42-4e29-952a-96563381f6ed	music
4ef11c56-6d5e-4549-ac12-68bf6d4e0e3c	Wait Until Dark	Unspecified open wound of wrist	179e9ddc-6bcf-4ccc-ab30-af7d5320759d	music
152e7e81-3c4b-440b-b507-e46da6c4ab0e	Bang Bang	Unsp inj less saphenous at lower leg level, left leg, init	e83a90b9-e476-431b-a602-97d672c0c863	film
c69d5f1d-a59e-41ca-b74f-8e93b9ec41a2	Body and Soul	Unilateral primary osteoarthritis, right hip	ea0c0033-65c6-4ab5-970d-ef05973c6e82	film
2064a42d-f721-4aef-b6f0-a2bab04d2c3c	One 2 Ka 4	Other reactive arthropathies, unspecified hand	dbbe9fa7-f11a-448d-8b26-e3ef10a6e677	audiobook
60bbcf26-410d-4789-a7a6-6ac0a4dee73a	Noah	Contact with knife, undetermined intent	09d7afc6-3fda-49bc-b3ec-4fa5ccf9c98a	film
14f487d9-83d7-4ff7-887a-cde148b35cab	Black Snake Moan	Displacement of int fix of bone of right forearm, subs	3a64a3e2-0e90-4d7f-a93d-8191377fe383	film
d27970ba-5356-4532-9cdf-ab2157ff671b	Cosmic Journey	Listerial endocarditis	9baa1513-aba4-4996-8c58-54377a3aee01	audiobook
7111b66b-452b-4ea3-94de-d4b9df8afc12	Snow Beast 	Chorioamnionitis, first trimester, other fetus	04c4960e-5a4f-48f4-98b9-443ecb257ac9	music
dec1f80b-9bd4-4570-8f22-df2cf57c039e	Scarlet Street	Lacerat unsp musc/fasc/tend at thigh level, right thigh	1903b034-108a-431b-918f-9c1f9b82ab22	audiobook
810fa726-a209-42fd-b90f-34a850e6b77e	Southern Comfort	Occupant (driver) of 3-whl mv injured in oth trnsp acc, init	b087d7cd-35c9-4dab-b807-61b00255f89c	film
48ad2dc0-ec6e-4a32-b418-6f750576e8a8	Murder, He Says	Posterior corneal pigmentations, right eye	23834e87-f0ea-45bc-ac08-571224a5dc9d	game
9d88c2b5-fadd-4242-ad5f-d7996683a487	Tully	Oth injury of musc/fasc/tend at thigh level, unsp thigh	dc5a25c5-4408-4129-bcbe-67e2c0c3e5c5	audiobook
baa71d99-dee1-4481-9c5a-53d8c6d037cc	Porywający Tytuł	Porywająca przygoda	5724b424-4956-4870-b54e-74d16c87c1be	game
052caf5c-4979-41e6-aa45-32fb141b8707	Wyśmienity tytułek	Porywająca przygoda	5724b424-4956-4870-b54e-74d16c87c1be	game
f31eef57-5cf3-4153-b9ff-0a044d67718d	Wyśmienity tytułeczek	Porywająca przygoda	5724b424-4956-4870-b54e-74d16c87c1be	game
ab0b02f5-f5f5-4b66-a53f-33331f5102ef	Wyśmienity tytułeczek	Porywająca przygoda	5724b424-4956-4870-b54e-74d16c87c1be	game
3da98c5f-43b8-4b47-af3d-f27aef95f415	Wyśmienity tytułeczek	Porywająca przygoda	5724b424-4956-4870-b54e-74d16c87c1be	game
ec339108-81b4-42b8-b938-7984bfdf60e4	Wyśmienity tytułeczek	Porywająca przygoda	5724b424-4956-4870-b54e-74d16c87c1be	game
eeaf8b8e-921d-4f53-8a5a-8ef0da867ceb	Wyśmienity tytułeczek	Porywająca przygoda	5724b424-4956-4870-b54e-74d16c87c1be	game
f3d5d56c-029a-4929-a1bd-9fd484908ebf	Nowy tytuł	Porywająca przygoda	5724b424-4956-4870-b54e-74d16c87c1be	game
1b1f7ab0-7f0c-4c2c-8296-10fc81034234	Unikalny tytuł	Porywająca przygoda	5724b424-4956-4870-b54e-74d16c87c1be	game
\.


--
-- Data for Name: uploader; Type: TABLE DATA; Schema: torrent; Owner: postgres
--

COPY torrent.uploader (id, name, recently_active, first_logged_in, recently_used_ip, first_used_ip) FROM stdin;
43329789-04f4-4826-90ad-bcc26b7159a3	mmchaffy1	2024-08-08 14:40:45	2022-05-27 03:57:46	166.251.162.57	168.166.8.116
4d0df9d5-a773-43f5-8077-cb08bf62839a	gyuryev2	2023-09-10 21:47:37	2022-05-06 18:27:40	57.42.195.185	78.73.93.150
af5bfaa0-02b9-4a48-b274-6c299c08aacf	edengel3	2023-11-16 17:13:18	2022-02-11 19:35:49	213.143.32.106	146.79.118.11
a1a4a096-126c-43c9-bf03-7b21e9a946b9	mbelcher4	2023-10-09 11:34:48	2022-01-19 19:34:12	171.252.27.150	97.138.225.8
13f2a810-c939-4f2f-84fc-b9ff2f55d869	bhutsby5	2024-10-17 17:07:27	2022-06-12 08:31:08	50.196.206.22	82.91.71.181
a9f0715f-ef43-43d4-b581-f7e684d53ca6	rsjollema6	2024-01-26 21:09:54	2022-08-09 04:44:07	125.255.7.59	233.15.215.50
129a86cf-4c77-41b8-b4cd-202a027293f6	hcatton7	2023-06-02 14:57:14	2022-03-31 15:10:44	30.174.152.97	108.157.228.77
2eec273d-a233-4fb2-a2ac-78921c2b9f8a	ypage8	2024-09-29 14:55:10	2022-03-17 05:56:20	69.113.88.237	24.78.122.88
c3684e50-5196-4894-a344-6330bc730a1c	lmadocjones9	2023-02-10 05:18:31	2022-07-22 01:38:24	68.141.54.175	152.131.221.83
98a3f0f1-b360-42e3-96e4-de3dbe21116c	dclementsona	2023-06-28 16:29:05	2022-03-09 17:19:51	39.149.14.71	119.5.107.84
9da03ce7-da6f-4baa-aebb-5a5f297edd92	vchidzoyb	2024-03-01 15:50:19	2022-01-18 07:02:12	215.33.249.81	132.226.215.52
4afcb6e9-d55a-498e-aa0d-212bd81c772c	schasierc	2024-09-14 18:24:24	2022-04-02 16:49:36	122.100.61.0	90.226.125.215
a24edb22-17bd-4ed5-aa4d-bab50c8e282f	egayned	2024-02-19 23:56:19	2022-05-12 09:04:57	162.94.4.141	28.240.117.45
1d3ffe92-4b8a-441e-93de-b591662f6c55	zpallatinae	2024-02-03 16:26:07	2022-08-24 08:16:33	142.215.60.135	149.214.166.242
d1e124a8-f952-41cb-9976-142750879da2	rhodgesf	2023-03-08 03:56:54	2022-06-18 14:31:34	22.205.196.52	97.102.161.73
d2d5543e-314b-40cc-85f9-f0aa9c09f8c9	btearnyg	2023-03-30 03:16:25	2022-03-17 20:47:00	12.194.223.57	176.82.27.230
75e8c225-2e80-4a08-8fc5-bdaa7e88464d	nbinesteadh	2024-02-07 06:39:47	2022-05-09 17:14:40	18.193.112.44	12.247.63.160
d1fbb1f1-6cd0-44ad-b521-10e9bf5b8c97	ogiordanoi	2024-09-03 08:35:11	2022-06-03 22:00:06	77.171.230.26	36.241.191.23
e021830b-050f-4871-b1d0-12f9be3912a9	ereichartzj	2023-11-10 02:30:48	2022-01-23 07:25:06	90.37.146.233	189.146.176.251
b1bb46bf-afcb-4dd7-b365-0caee244f733	kkamienskik	2024-08-09 17:38:37	2022-01-25 21:54:48	68.3.82.84	160.42.0.42
c8d69cb9-fc66-48d3-919a-c029a8d228c0	pmellodyl	2024-06-25 10:57:02	2022-02-21 05:31:00	190.217.161.118	90.206.36.187
664c6d57-faa9-43c3-95cc-1e7c23715b97	dcicerom	2024-04-16 10:32:59	2022-02-03 14:06:50	150.193.222.42	99.217.105.146
1bd4b85a-c677-49b0-99d2-8df21e1453c9	pketchern	2024-06-19 08:04:58	2022-09-05 16:34:13	107.123.87.21	45.74.229.92
112fdaa6-0ae1-4aea-9c18-60315bcdcd5e	ptumasiano	2024-09-07 15:29:11	2022-06-21 20:02:19	165.197.28.121	228.245.198.72
42a1e621-fc79-48d2-9977-d59a538fcde5	bgilderoyp	2024-09-27 06:49:03	2022-04-05 16:25:50	130.146.164.42	202.124.158.253
2ba927ab-c5e4-401f-82c0-f566f6df8f8e	mcadoganq	2024-08-21 22:15:43	2022-06-18 18:44:55	219.15.5.182	236.167.236.241
12fb141a-0cf3-4005-ad57-3ca25df6bfd4	pjeanequinr	2024-05-17 12:06:03	2022-05-27 22:47:26	163.240.7.121	117.109.153.195
97f91c15-b90e-4570-ac5a-32a701d0765b	rmains	2023-03-26 03:17:59	2022-04-14 01:08:14	46.166.61.21	211.142.233.43
f211d427-a604-4773-add5-06b1e21342bb	abonnert	2024-10-10 11:16:06	2022-06-19 18:36:58	35.206.128.128	185.145.58.71
e96a7525-52f7-4dea-8d5c-dc9a60e8e167	achilcottu	2024-05-04 04:49:33	2022-06-30 13:40:47	218.225.23.103	69.57.81.169
8ed51a79-e1c7-495a-8819-d6a8a77ab630	dgillittv	2023-09-25 10:11:53	2022-02-22 23:19:46	93.106.129.43	120.192.97.143
4650a8bd-672a-4c6b-9938-b4b292b21e82	ncruikshankw	2024-10-09 15:43:06	2022-08-17 21:12:24	209.214.83.35	219.219.232.231
75df44b2-6dd7-4eee-a92f-daa430145a11	slawleex	2024-01-15 03:09:28	2022-02-02 05:57:41	201.81.39.159	21.107.127.183
2206ba91-9b2b-41be-b1cc-4e559c3156f6	bmatiebey	2024-09-04 07:09:27	2022-03-30 10:51:15	166.252.58.26	68.112.232.97
cacc35b1-72e6-4fdd-bedd-2e9e81927ee1	vschoroderz	2024-09-17 20:15:34	2022-05-19 08:54:20	64.245.155.159	107.195.7.203
9db614e3-d420-4c0c-a70d-6cdad5a9e7d9	amcilheran10	2023-09-22 17:55:23	2022-07-16 08:19:19	22.113.82.44	38.209.32.104
b47501d7-614a-416a-bb06-cb0f886981f0	ksculpher11	2024-02-23 20:40:00	2022-04-12 09:45:04	58.222.118.41	207.208.128.8
a38d4065-6877-4a6e-8422-d09b7ca3285d	amailey12	2024-02-27 22:52:12	2022-06-07 14:28:31	169.106.70.57	22.239.54.76
ecddf7c0-4c18-4fdf-8a18-e8d2b12587e5	jgimson13	2024-04-25 13:14:42	2022-02-25 16:24:58	11.54.250.35	213.57.92.231
15947aaf-c5d8-47db-a88b-92423d8fceed	rhollindale14	2024-06-03 05:13:53	2022-01-25 03:23:33	23.140.2.24	119.55.60.107
eaa7c2dc-e862-4e78-9040-be988fc6a58f	jturtle15	2024-10-23 05:09:43	2022-08-25 03:43:38	85.100.47.30	213.152.80.57
b9debc18-4ebd-4517-a1c8-046d4d787899	bparsonage16	2023-05-22 01:19:21	2022-03-16 14:58:20	6.196.254.101	205.169.212.103
c307abf1-b57b-4934-a224-42e46f4e0686	psowray17	2024-05-11 22:14:02	2022-05-29 04:04:37	35.54.153.233	149.91.1.249
f453a1d0-2037-499e-8ff6-f6d18a417e42	bdurtnall18	2023-08-25 13:47:11	2022-01-27 18:31:48	158.42.7.159	132.29.245.188
829c062f-d408-4d4d-b2d7-3659f4a6578a	lnassy19	2024-08-09 21:10:27	2022-07-31 04:11:15	74.180.248.4	143.114.3.143
a6350642-884a-47df-82d7-98194b28c170	btremblett1a	2023-11-26 22:18:47	2022-08-26 15:30:03	47.184.71.64	219.57.17.197
0c1aae64-49a4-410d-aae7-8c6845b1fadc	sadamczyk1b	2024-01-18 01:39:49	2022-09-01 02:15:22	65.168.211.127	252.62.58.98
75dec64d-1149-4bd4-b1b5-990078d119cd	etalkington1c	2024-08-11 03:11:12	2022-05-29 03:15:35	116.20.37.79	240.141.50.88
9b6c3fff-22ab-4417-9aa2-50b5b5f74c9a	rjozaitis1d	2024-09-02 11:38:24	2022-03-01 18:57:07	46.247.5.214	147.210.84.149
4fb57a62-c8bd-4888-93ba-1e9caff307f6	jtowey1e	2024-06-10 03:13:22	2022-07-02 05:04:45	184.91.203.161	245.38.215.108
f828502b-20ac-4811-8dbc-887f555d85ee	dbellamy1f	2024-02-11 06:50:38	2022-04-23 13:52:37	236.121.60.64	86.177.158.67
310a4dc2-3a54-4d3c-8580-9be94207aea1	afruin1g	2024-01-03 08:29:17	2022-05-06 11:14:07	150.82.74.153	155.222.64.10
d96bb090-1f7c-4b18-9cc0-7d26ad847d8e	lcamp1h	2023-08-19 08:50:05	2022-07-22 05:28:15	186.58.221.48	225.70.127.141
d28b1b71-6292-4b47-b597-fd617c7063e6	bfinkle1i	2023-07-30 16:05:07	2022-09-10 18:56:19	111.11.0.130	223.37.220.179
b362c61d-ca08-4d35-b46b-e47a02a94338	nhansley1j	2024-06-11 08:31:33	2022-06-05 13:31:04	73.176.227.82	57.13.131.252
78c38e0a-446a-42df-898c-8cc6ce4c3e0d	jeliff1k	2024-02-12 14:27:00	2022-08-15 13:02:13	45.175.26.193	106.6.42.32
6ca3c632-0823-4163-ae52-b517be42bf03	gsacchetti1l	2023-09-18 01:37:12	2022-02-21 23:21:52	238.129.158.184	196.189.90.186
9b9a96dc-898a-4b48-8c56-9566b96539bd	snyssens1m	2023-04-11 16:11:36	2022-03-13 11:28:51	59.45.161.252	148.213.84.198
27a67f4b-5fba-4901-8575-efdab9524bf1	ctully1n	2023-06-18 22:01:37	2022-05-20 14:29:41	196.29.23.153	60.174.199.98
3109e086-0d77-411a-9d78-e03a0b2f407a	jminard1o	2024-10-16 09:17:18	2022-08-25 03:33:02	88.228.226.75	145.133.6.144
bc5b7ecf-53a5-4259-a367-cebf950d735d	amcclosh1p	2024-09-29 09:24:29	2022-03-06 12:05:29	192.34.78.11	159.139.158.215
5cf95429-8b70-4dc7-b98b-42d981577d08	eackhurst1q	2024-08-05 21:32:00	2022-02-23 08:14:11	169.136.18.153	203.108.27.220
6bbefd0e-1d47-4522-a030-0f0908067f9d	tbloodworth1r	2024-09-06 14:40:27	2022-06-19 11:38:40	216.7.10.194	186.185.45.145
45c3daee-e335-4cc2-a603-398d4dc82616	cdogerty1s	2023-09-12 23:16:45	2022-02-19 05:14:16	41.92.196.248	81.208.149.134
07c08cbe-05af-4d07-b948-6397497a7c00	nklees1t	2024-07-09 21:50:00	2022-02-06 00:34:26	9.173.180.175	232.177.21.77
e12210c9-f564-4fdf-9a3d-172d23c07a90	tlumly1u	2023-07-15 20:45:27	2022-07-30 02:02:49	195.140.221.200	254.157.185.103
d9caa29e-2ff2-4ebe-9cf0-58f32fca4db4	jboleyn1v	2023-05-06 16:24:49	2022-07-02 00:53:38	238.119.174.199	40.192.18.221
463d812a-a5bb-484c-bcae-08eef54e8f89	mminghi1w	2024-02-20 12:55:17	2022-04-14 08:08:09	76.215.167.211	1.138.13.34
cedc74ca-5ad5-49b5-b51a-a54c852738fe	hlathwood1x	2024-04-30 20:37:29	2022-09-12 19:53:15	141.243.17.172	190.0.252.226
bf96c44a-90fa-445e-92ac-1ddaec6dee93	rrickerd1y	2024-04-05 14:06:02	2022-05-21 11:36:22	16.203.240.110	62.65.129.137
f8f832c8-c1ff-4551-9910-e3b375bec6d7	fmayo1z	2023-09-24 11:16:48	2022-07-12 18:35:56	159.182.150.101	21.204.236.242
c8e25b96-cb63-4e87-819c-9c07e86c0ca0	fmurthwaite20	2024-04-16 12:51:41	2022-07-04 07:56:19	178.134.185.140	6.34.12.163
1873db59-1562-4577-924e-7a7572037b2d	mwilloughey21	2023-08-17 16:21:50	2022-08-08 23:59:56	32.127.30.88	5.106.28.207
b747b195-e30f-4abb-a482-826fd60ad271	jinnett22	2024-05-24 04:53:16	2022-07-20 08:07:12	54.226.208.175	65.164.113.209
977028b5-4105-4bea-b1e9-738c6ca1c753	ggipp23	2024-04-15 15:07:17	2022-02-27 06:54:23	84.113.191.23	11.84.191.28
4dbfadad-b431-414c-8b68-8dd663109af1	dbrennan24	2024-06-12 22:16:17	2022-01-22 07:12:36	87.27.4.5	60.53.223.3
c6b3e07c-f565-40db-9d50-d136ce9c1104	jgrogona25	2024-10-20 17:42:54	2022-04-30 19:06:41	224.121.19.93	92.231.232.120
0ebbfda8-2b34-4701-b707-74932400204b	oshires26	2023-04-07 18:21:38	2022-08-17 15:00:28	186.44.20.37	148.125.194.17
d02f9eb8-d1cb-4532-bdcc-0b83ca79ea78	mpounsett27	2023-10-05 10:00:44	2022-04-27 12:00:51	25.24.251.28	215.134.221.27
1eaf54aa-2160-473a-b7d6-4e394364738a	llatter28	2024-09-06 02:12:33	2022-04-07 00:32:07	234.238.75.195	104.82.164.245
c15deacc-b36c-4540-aac3-e4e91bd82119	tvasenin29	2024-05-15 12:54:27	2022-09-09 01:13:44	57.61.237.97	247.252.126.176
52c52b56-e36c-4600-ab17-f30b8afe8506	rwrankmore2a	2024-05-09 22:52:12	2022-09-03 04:13:38	201.186.215.81	30.218.166.249
8642ffed-4629-480c-a2e5-6d238ed3b2af	raldren2b	2024-01-22 22:36:50	2022-07-21 03:24:59	8.130.205.124	174.132.53.72
1c073ee8-de42-48e9-8408-ec8b7ea6c61d	ebedborough2c	2024-09-03 04:28:10	2022-06-13 12:50:22	190.36.228.134	87.191.8.197
db21ec12-a5da-4e21-9843-e87fc7f94d0a	bteaz2d	2024-03-15 14:28:52	2022-04-24 18:31:08	225.176.80.111	224.164.142.110
83460de9-1991-4f3f-b14c-e52f8728b533	sblaschke2e	2023-04-16 13:39:47	2022-03-06 01:12:45	96.111.205.212	115.33.141.16
37c66b8f-ac42-4e29-952a-96563381f6ed	fkarpenko2f	2024-01-25 10:31:32	2022-07-29 16:19:39	219.187.92.203	122.113.190.42
179e9ddc-6bcf-4ccc-ab30-af7d5320759d	jangeli2g	2024-07-07 16:44:08	2022-08-27 05:44:46	167.6.24.212	176.238.156.35
e83a90b9-e476-431b-a602-97d672c0c863	drandall2h	2024-08-18 06:39:48	2022-02-12 22:15:14	241.48.131.236	217.113.237.57
ea0c0033-65c6-4ab5-970d-ef05973c6e82	thindenberger2i	2023-03-29 03:50:30	2022-01-23 00:56:57	154.176.16.182	156.254.148.138
dbbe9fa7-f11a-448d-8b26-e3ef10a6e677	rduddle2j	2023-04-13 16:48:05	2022-07-11 00:02:55	117.135.160.123	78.62.127.240
09d7afc6-3fda-49bc-b3ec-4fa5ccf9c98a	rtampion2k	2023-05-24 08:54:29	2022-02-22 05:05:12	99.22.237.20	95.118.190.167
3a64a3e2-0e90-4d7f-a93d-8191377fe383	ecottom2l	2024-07-04 21:50:41	2022-06-24 06:24:49	190.198.67.144	120.34.114.125
9baa1513-aba4-4996-8c58-54377a3aee01	mlipprose2m	2024-06-03 09:23:14	2022-02-12 03:36:12	70.168.137.222	31.165.194.98
04c4960e-5a4f-48f4-98b9-443ecb257ac9	mspain2n	2024-04-26 10:11:11	2022-05-23 11:53:28	229.204.57.217	255.199.98.243
1903b034-108a-431b-918f-9c1f9b82ab22	mrichen2o	2023-04-20 16:47:06	2022-01-22 06:28:21	182.158.50.83	157.231.92.43
b087d7cd-35c9-4dab-b807-61b00255f89c	aparkins2p	2024-02-07 14:59:59	2022-05-08 18:37:03	51.18.250.168	175.242.160.25
23834e87-f0ea-45bc-ac08-571224a5dc9d	rcutbush2q	2023-07-09 17:45:48	2022-02-16 10:40:43	219.60.83.234	60.100.1.85
dc5a25c5-4408-4129-bcbe-67e2c0c3e5c5	kfollows2r	2024-08-17 12:45:44	2022-06-20 01:02:31	159.187.31.255	254.10.94.20
5724b424-4956-4870-b54e-74d16c87c1be	gcavy0	2024-11-07 21:22:20.792544	2022-05-20 04:52:32	127.0.0.1	132.146.156.227
\.


--
-- Name: resource resource_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resource
    ADD CONSTRAINT resource_pkey PRIMARY KEY (id);


--
-- Name: resource resource_url_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resource
    ADD CONSTRAINT resource_url_key UNIQUE (url);


--
-- Name: uploader uploader_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uploader
    ADD CONSTRAINT uploader_name_key UNIQUE (name);


--
-- Name: uploader uploader_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uploader
    ADD CONSTRAINT uploader_pkey PRIMARY KEY (id);


--
-- Name: audio_book audio_book_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.audio_book
    ADD CONSTRAINT audio_book_pkey PRIMARY KEY (id);


--
-- Name: book_archetype book_archetype_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.book_archetype
    ADD CONSTRAINT book_archetype_pkey PRIMARY KEY (id);


--
-- Name: book_instance book_instance_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.book_instance
    ADD CONSTRAINT book_instance_pkey PRIMARY KEY (share_id);


--
-- Name: category category_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.category
    ADD CONSTRAINT category_pkey PRIMARY KEY (name);


--
-- Name: ebook ebook_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.ebook
    ADD CONSTRAINT ebook_pkey PRIMARY KEY (id);


--
-- Name: film_archetype film_archetype_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.film_archetype
    ADD CONSTRAINT film_archetype_pkey PRIMARY KEY (id);


--
-- Name: film_instance film_instance_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.film_instance
    ADD CONSTRAINT film_instance_pkey PRIMARY KEY (share_id);


--
-- Name: game_archetype game_archetype_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.game_archetype
    ADD CONSTRAINT game_archetype_pkey PRIMARY KEY (id);


--
-- Name: game_instance game_instance_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.game_instance
    ADD CONSTRAINT game_instance_pkey PRIMARY KEY (share_id);


--
-- Name: music_archetype music_archetype_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.music_archetype
    ADD CONSTRAINT music_archetype_pkey PRIMARY KEY (id);


--
-- Name: music_instance music_instance_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.music_instance
    ADD CONSTRAINT music_instance_pkey PRIMARY KEY (share_id);


--
-- Name: operating_system operating_system_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.operating_system
    ADD CONSTRAINT operating_system_pkey PRIMARY KEY (name);


--
-- Name: resource resource_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.resource
    ADD CONSTRAINT resource_pkey PRIMARY KEY (id);


--
-- Name: resource resource_url_key; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.resource
    ADD CONSTRAINT resource_url_key UNIQUE (url);


--
-- Name: share share_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.share
    ADD CONSTRAINT share_pkey PRIMARY KEY (resource_id);


--
-- Name: uploader uploader_name_key; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.uploader
    ADD CONSTRAINT uploader_name_key UNIQUE (name);


--
-- Name: uploader uploader_pkey; Type: CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.uploader
    ADD CONSTRAINT uploader_pkey PRIMARY KEY (id);


--
-- Name: rid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX rid ON public.resource USING btree (id);


--
-- Name: uid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX uid ON public.uploader USING btree (id);


--
-- Name: url_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX url_index ON public.resource USING btree (url);


--
-- Name: abr; Type: INDEX; Schema: torrent; Owner: postgres
--

CREATE INDEX abr ON torrent.audio_book USING btree (read_by varchar_pattern_ops);


--
-- Name: bau; Type: INDEX; Schema: torrent; Owner: postgres
--

CREATE INDEX bau ON torrent.book_archetype USING btree (author varchar_pattern_ops);


--
-- Name: btitle; Type: INDEX; Schema: torrent; Owner: postgres
--

CREATE INDEX btitle ON torrent.book_archetype USING btree (title varchar_pattern_ops);


--
-- Name: ftitle; Type: INDEX; Schema: torrent; Owner: postgres
--

CREATE INDEX ftitle ON torrent.film_archetype USING btree (title varchar_pattern_ops);


--
-- Name: gtitle; Type: INDEX; Schema: torrent; Owner: postgres
--

CREATE INDEX gtitle ON torrent.game_archetype USING btree (title varchar_pattern_ops);


--
-- Name: ip; Type: INDEX; Schema: torrent; Owner: postgres
--

CREATE INDEX ip ON torrent.uploader USING gist (recently_used_ip, first_used_ip);


--
-- Name: sd; Type: INDEX; Schema: torrent; Owner: postgres
--

CREATE INDEX sd ON torrent.share USING btree (description varchar_pattern_ops);


--
-- Name: st; Type: INDEX; Schema: torrent; Owner: postgres
--

CREATE INDEX st ON torrent.share USING btree (title varchar_pattern_ops);


--
-- Name: url_index; Type: INDEX; Schema: torrent; Owner: postgres
--

CREATE INDEX url_index ON torrent.resource USING btree (url text_pattern_ops);


--
-- Name: game_archetype before_adding_game_archetype; Type: TRIGGER; Schema: torrent; Owner: postgres
--

CREATE TRIGGER before_adding_game_archetype BEFORE INSERT ON torrent.game_archetype FOR EACH ROW EXECUTE FUNCTION public.update_games_os();


--
-- Name: share cleanup_resource; Type: TRIGGER; Schema: torrent; Owner: postgres
--

CREATE TRIGGER cleanup_resource AFTER DELETE ON torrent.share FOR EACH ROW EXECUTE FUNCTION public.cleanup_resource();


--
-- Name: audio_book audio_book_source_book_id_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.audio_book
    ADD CONSTRAINT audio_book_source_book_id_fkey FOREIGN KEY (source_book_id) REFERENCES torrent.book_archetype(id);


--
-- Name: book_instance book_instance_archetype_id_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.book_instance
    ADD CONSTRAINT book_instance_archetype_id_fkey FOREIGN KEY (archetype_id) REFERENCES torrent.book_archetype(id);


--
-- Name: book_instance book_instance_share_id_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.book_instance
    ADD CONSTRAINT book_instance_share_id_fkey FOREIGN KEY (share_id) REFERENCES torrent.share(resource_id);


--
-- Name: ebook ebook_source_book_id_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.ebook
    ADD CONSTRAINT ebook_source_book_id_fkey FOREIGN KEY (source_book_id) REFERENCES torrent.book_archetype(id);


--
-- Name: film_instance film_instance_archetype_id_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.film_instance
    ADD CONSTRAINT film_instance_archetype_id_fkey FOREIGN KEY (archetype_id) REFERENCES torrent.film_archetype(id);


--
-- Name: film_instance film_instance_share_id_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.film_instance
    ADD CONSTRAINT film_instance_share_id_fkey FOREIGN KEY (share_id) REFERENCES torrent.share(resource_id);


--
-- Name: game_archetype game_archetype_operating_system_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.game_archetype
    ADD CONSTRAINT game_archetype_operating_system_fkey FOREIGN KEY (operating_system) REFERENCES torrent.operating_system(name);


--
-- Name: game_instance game_instance_archetype_id_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.game_instance
    ADD CONSTRAINT game_instance_archetype_id_fkey FOREIGN KEY (archetype_id) REFERENCES torrent.game_archetype(id);


--
-- Name: game_instance game_instance_share_id_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.game_instance
    ADD CONSTRAINT game_instance_share_id_fkey FOREIGN KEY (share_id) REFERENCES torrent.share(resource_id) ON DELETE CASCADE;


--
-- Name: music_instance music_instance_archetype_id_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.music_instance
    ADD CONSTRAINT music_instance_archetype_id_fkey FOREIGN KEY (archetype_id) REFERENCES torrent.music_archetype(id);


--
-- Name: music_instance music_instance_share_id_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.music_instance
    ADD CONSTRAINT music_instance_share_id_fkey FOREIGN KEY (share_id) REFERENCES torrent.share(resource_id);


--
-- Name: share share_category_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.share
    ADD CONSTRAINT share_category_fkey FOREIGN KEY (category) REFERENCES torrent.category(name);


--
-- Name: share share_resource_id_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.share
    ADD CONSTRAINT share_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES torrent.resource(id) ON DELETE CASCADE;


--
-- Name: share share_uploader_id_fkey; Type: FK CONSTRAINT; Schema: torrent; Owner: postgres
--

ALTER TABLE ONLY torrent.share
    ADD CONSTRAINT share_uploader_id_fkey FOREIGN KEY (uploader_id) REFERENCES torrent.uploader(id);


--
-- Name: PROCEDURE add_audiobook(IN p_title character varying, IN p_book_archetype uuid, IN p_audio_book uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.add_audiobook(IN p_title character varying, IN p_book_archetype uuid, IN p_audio_book uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean) TO contributor;


--
-- Name: PROCEDURE add_ebook(IN p_title character varying, IN p_book_archetype uuid, IN p_ebook uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.add_ebook(IN p_title character varying, IN p_book_archetype uuid, IN p_ebook uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean) TO contributor;


--
-- Name: PROCEDURE add_film(IN p_title character varying, IN p_film_archetype uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.add_film(IN p_title character varying, IN p_film_archetype uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean) TO contributor;


--
-- Name: PROCEDURE add_game(IN p_title character varying, IN p_game_archetype_id uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.add_game(IN p_title character varying, IN p_game_archetype_id uuid, IN p_uploader_id uuid, IN file_sha bytea, IN p_url text, IN p_recent_uploader_ip inet, IN p_description character varying, IN p_size_in_bytes bigint, IN p_is_legal boolean) TO contributor;


--
-- Name: TABLE admin_example_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.admin_example_view TO torrent_admin;


--
-- Name: TABLE all_shares; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.all_shares TO contributor;


--
-- Name: TABLE share_movie_details; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.share_movie_details TO contributor;


--
-- Name: TABLE suspicious_ips; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.suspicious_ips TO torrent_admin;


--
-- Name: TABLE suspicious_urls_in_a_week; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.suspicious_urls_in_a_week TO torrent_admin;


--
-- Name: TABLE game_archetype; Type: ACL; Schema: torrent; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE torrent.game_archetype TO contributor;


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database cluster dump complete
--

