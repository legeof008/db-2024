SHOW DATABASES;

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
MATCH (existing:Game)
  WHERE existing.name = row.Game
CREATE (t:Averages {viewers: row.Avg_viewers, channels: row.Avg_channels, viewer_ratio: viewer: row.Avg_viewer_ratio})
CREATE (h:Viewings {watched: row.Hours_watched, streamed: row.Hours_streamed})
CREATE (p:Peaks {viewers: row.Peak_viewers, channels: row.Peak_channels})
CREATE (s:Streamers {streamers: row.Streamers})
CREATE (n:TwitchRank {rank: row.Rank, month: row.Month, year: row.Year})
CREATE (t)-[:HAS_AVERAGES_OF]->(existing)
CREATE (h)-[:HAS_VIEWINGS_OF]->(existing)
CREATE (p)-[:HAS_PEAKS_OF]->(existing)
CREATE (s)-[:IS_STREAMED_BY]->(existing)
CREATE (n)-[:WAS_RANKED]->(existing);

MATCH (n)
DETACH DELETE n;

MATCH (a)-[r]->(b)
RETURN a, r, bt;

MATCH (g:Game)<-[:DESCRIBES]-(c:ShortDescription)
MATCH (g:Game)<-[:CREATED]-(d:Creators)
OPTIONAL MATCH (g:Game)<-[:HAS_TWITCH_STATS]-(t:TwitchStats)
RETURN g.name AS name, date(g.date) AS date, c.content AS short_description,
       collect(t) AS twitch_stats, d.developer AS developer;

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
  null as observed_rankings,
  ranks,
  release_year,
  most_recent_ranking_year,
  CASE
    WHEN long_description CONTAINS 'team' THEN true
    ELSE false
    END AS contains_team_in_description;

