SHOW DATABASES;


LOAD CSV WITH HEADERS FROM 'file:///steam.csv' AS row
MERGE (d:Creators {developer: row.developer, publisher: row.publisher})
MERGE (g:Game {steam_id: row.appid, name: row.name, date: row.release_date})
  ON CREATE SET g.name = row.name, g.date = row.release_date
MERGE (d)-[:CREATED]->(g);

// Old
LOAD CSV WITH HEADERS FROM 'file:///steam.csv' AS row
CREATE(d:Creators {developer: row.developer, publisher: row.publisher})
        -[r:CREATED]->(g:Game {steam_id: row.appid, name: row.name, date: row.release_date});


LOAD CSV WITH HEADERS FROM 'file:///desc_unsecaped.csv' AS row
MATCH (existing:Game)
  WHERE existing.steam_id = row.steam_appid
CREATE (long:LongDescription {content: row.detailed_description})
CREATE (short:ShortDescription {content: row.short_description})
CREATE (about:AboutGame {content: row.about_the_game})
CREATE (long)-[:DESCRIBES]->(existing)
CREATE (short)-[:DESCRIBES]->(existing)
CREATE (about)-[:IS_ABOUT]->(existing)
CREATE (short)-[:IS_SHORT_FOR]->(long)
CREATE (long)-[:IS_LONG_FOR]->(short)
CREATE (about)-[:IS_SUPPLEMENT_FOR]->(short);

LOAD CSV WITH HEADERS FROM 'file:///twitch.csv' AS row
MERGE (existing:Game {name: row.Game})
CREATE (t:Averages {viewers: row.Avg_viewers, channels: row.Avg_channels, viewer_ratio: row.Avg_viewer_ratio})
CREATE (h:Viewings {watched: row.Hours_watched, streamed: row.Hours_streamed})
CREATE (p:Peaks {viewers: row.Peak_viewers, channels: row.Peak_channels})
CREATE (s:Streamers {streamers: row.Streamers})
MERGE (n:TwitchRank {rank: row.Rank, month: row.Month, year: row.Year})
  ON CREATE SET n.Rank = row.Rank, n.Month = row.Month, n.Year = row.Year
CREATE (t)-[:HAS_AVERAGES_OF]->(existing)
CREATE (h)-[:HAS_VIEWINGS_OF]->(existing)
CREATE (p)-[:HAS_PEAKS_OF]->(existing)
CREATE (s)-[:IS_STREAMED_BY]->(existing)
CREATE (n)-[:WAS_RANKED]->(existing);

MATCH (n:Location)
DETACH DELETE n;

MATCH (a)-[r]->(b)
RETURN a, r, bt;

PROFILE
MATCH (g:Game)<-[:DESCRIBES]-(c:ShortDescription)
MATCH (g:Game)<-[:CREATED]-(d:Creators)
OPTIONAL MATCH (g:Game)<-[:HAS_TWITCH_STATS]-(t:TwitchStats)
RETURN g.name AS name, date(g.date) AS date, c.content AS short_description,
       collect(t) AS twitch_stats, d.developer AS developer;

CREATE INDEX creators_developer_index IF NOT EXISTS FOR (d:Creators) ON (d.developer);

CREATE TEXT INDEX  long_description_fulltext_index FOR (d:LongDescription) ON (d.content);

CREATE TEXT INDEX  short_description_content_index FOR (d:ShortDescription) ON (d.content);

CREATE TEXT INDEX  about_description_content_index FOR (d:AboutGame) ON (d.content);


CREATE INDEX game_index IF NOT EXISTS FOR (g:Game) ON (g.name);

CREATE INDEX t_rank_index IF NOT EXISTS FOR (t:TwitchRank) ON (t.rank, t.year);

CREATE INDEX t_month_index IF NOT EXISTS FOR (t:TwitchRank) ON (t.month);


DROP INDEX twitch_stats_rank_month_year_index IF EXISTS;

DROP INDEX short_description_content_index IF EXISTS;

DROP INDEX creators_developer_index IF EXISTS;

DROP INDEX twitch_stats_rank_month_year_index IF EXISTS;

DROP INDEX long_desc_index IF EXISTS;

DROP INDEX game_index IF EXISTS;

DROP INDEX t_rank_index IF EXISTS;

DROP INDEX t_month_index IF EXISTS;

DROP INDEX long_description_fulltext_index IF EXISTS;

DROP INDEX short_description_content_index IF EXISTS;

DROP INDEX about_description_content_index IF EXISTS;


MATCH (g:Game)<-[:CREATED]-(d:Creators)
OPTIONAL MATCH (g:Game)<-[:HAS_TWITCH_STATS]-(t:TwitchStats)
RETURN d.developer AS studio, d.publisher AS publisher, count(DISTINCT g) AS released_games,
       collect(t) AS twitch_stats

MATCH (g:Game)<-[:DESCRIBES]-(d:LongDescription)
OPTIONAL MATCH (g:Game)<-[h:WAS_RANKED]-(t:TwitchRank)
  WHERE t.rank > '30'
WITH
  g.name AS name,
  d.content AS long_description,
  count(DISTINCT t) AS observed_rankings,
  g.date AS release_year,
  collect(t) AS ranks,
  max(t.year) AS most_recent_ranking_year
  WHERE
  observed_rankings < 5 AND observed_rankings > 1
RETURN
  name,
  long_description,
  observed_rankings,
  ranks,
  release_year,
  most_recent_ranking_year,
  CASE
    WHEN long_description CONTAINS 'team' THEN true
    ELSE false
    END AS contains_team_in_description
UNION
MATCH (g:Game)<-[:DESCRIBES]-(d:LongDescription)
OPTIONAL MATCH (g:Game)<-[h:WAS_RANKED]-(t:TwitchRank)
  WHERE t.rank > '30'
WITH
  g.name AS name,
  d.content AS long_description,
  [t] AS ranks,
  g.date AS release_year,
  [t.year] AS most_recent_ranking_year,

  count(DISTINCT t) AS observed_rankings
  WHERE observed_rankings >= 5 OR observed_rankings = 1

RETURN
  name,
  long_description,
  null AS observed_rankings,
  ranks,
  release_year,
  most_recent_ranking_year,
  CASE
    WHEN long_description CONTAINS 'team' THEN true
    ELSE false
    END AS contains_team_in_description
  LIMIT 25;

MATCH (g:Game)<-[:DESCRIBES]-(d:LongDescription)
OPTIONAL MATCH (g:Game)<-[h:WAS_RANKED]-(t:TwitchRank)
WITH
  g.name AS name,
  d.content AS long_description,
  count(DISTINCT t) AS observed_rankings,
  collect(t) AS ranks,
  g.date AS release_year,
  max(t.year) AS most_recent_ranking_year
  WHERE
  observed_rankings > 1
RETURN
  name,
  long_description,
  observed_rankings,
  ranks,
  release_year,
  most_recent_ranking_year,
  CASE
    WHEN long_description CONTAINS 'shooter' THEN true
    ELSE false
    END AS contains_shooter_in_description;

// CREATE CONSTRAINT creators_unique IF NOT EXISTS
// FOR (c:Creators)
// REQUIRE (c.developer, c.publisher) IS UNIQUE;
//
// CREATE CONSTRAINT game_steam_id_unique IF NOT EXISTS
// FOR (g:Game)
// REQUIRE g.steam_id IS UNIQUE;
//
// CREATE CONSTRAINT twitch_rank_unique IF NOT EXISTS
// FOR (t:TwitchRank)
// REQUIRE (t.rank, t.month, t.year) IS UNIQUE;

MATCH (studio:Creators)
WITH studio,
     rand() * 180 - 90 AS latitude,
     rand() * 360 - 180 AS longitude
MERGE (loc:Location {latitude: latitude, longitude: longitude})
MERGE (studio)-[:LOCATED_IN]->(loc);

MATCH (node1)-[relationship:LOCATED_AT]->(node2)
DELETE relationship;

WITH point({latitude: 52.2297, longitude: 21.0122}) AS warsaw_point, 1000 AS max_distance_km
MATCH (studio:Creators)-[:LOCATED_IN]->(loc:Location)
WITH studio, warsaw_point, point({latitude: loc.latitude, longitude: loc.longitude}) AS studio_point, loc
  WHERE point.distance(warsaw_point, studio_point) <= max_distance_km * 1000
RETURN studio.developer AS studio_name, loc.latitude AS latitude, loc.longitude AS longitude,
       point.distance(warsaw_point, studio_point) / 1000 AS distance_in_km
  ORDER BY distance_in_km;

MATCH (studio1:Creators)-[:LOCATED_IN]->(loc1:Location)
WITH studio1, loc1
MATCH (studio2:Creators)-[:LOCATED_IN]->(loc2:Location)
  WHERE elementId(studio1) < elementId(studio2)
  AND point.distance(point({latitude: loc1.latitude, longitude: loc1.longitude}), point({latitude:  loc2.latitude, longitude: loc2.
    longitude})) <= 200 * 1000
RETURN studio1.developer AS Studio1, studio2.developer AS Studio2,
       point.distance(point({latitude: loc1.latitude, longitude: loc1.longitude}), point({latitude:  loc2.latitude, longitude: loc2.
         longitude})) / 1000 AS distance_in_km
  ORDER BY distance_in_km;

MATCH path = (studio1:Creators)-[r:NEAR*]-(studio2:Creators)
  WHERE elementId(studio1) < elementId(studio2)
RETURN studio1.name AS Studio1, studio2.name AS Studio2, path,
       reduce(total_distance = 0, rel IN relationships(path) | total_distance + rel.distance) AS total_distance;


CREATE INDEX location_index IF NOT EXISTS FOR (l:Location) on (l.longitude,l.latitude);
