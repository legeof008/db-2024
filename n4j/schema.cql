SHOW DATABASES;

LOAD CSV WITH HEADERS FROM 'file:///steam.csv' AS row
CREATE(d:Creators {developer: row.developer, publisher: row.publisher})
        -[r:CREATED]->(g:Game {id: row.appid, name: row.name, date: row.release_date});

LOAD CSV WITH HEADERS FROM 'file:///steam_description_data.csv' AS row
MATCH (existing:Game {id: toInteger(row.steam_appid)})
CREATE (long:LongDescription {content: row.detailed_description})
CREATE (short:ShortDescription {content: row.short_description})
CREATE (about:AboutGame {content: row.about_the_game})
CREATE (long)-[:DESCRIBES]->(existing);
CREATE (short)-[:DESCRIBES]->(existing);
CREATE (about)-[:IS_ABOUT]->(existing);
CREATE (short)-[:IS_SHORT_FOR]->(long);
CREATE (long)-[:IS_LONG_FOR]->(short);
CREATE (about)-[:IS_SUPPLEMENT_FOR]->(short);

MATCH (p:LongDescription)
RETURN p.content;

MATCH (p:SkibidiToilet)
DELETE p

MATCH (n)
DETACH DELETE n;

MATCH (a)-[r]->(b)
RETURN a, r, bt;
