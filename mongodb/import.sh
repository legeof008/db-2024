#!/bin/bash

connection_uri='mongodb://root:example@localhost:27017'
dbName='torrent_games'
filenames=("steam" "media" "description")

for filename in "${filenames[@]}"; do
  json="$filename.json"
  collection="$filename"
  echo -e "\e[32mProcessing $filename.json with fields in $field to $collection\e[0m"
  mongoimport --uri=$connection_uri --db=$dbName --collection=$collection --authenticationDatabase=admin --file=$json
  echo -e "\e[32mCompleted processing $filename.json to $collection\e[0m"
done
echo -e "\e[32mCompleted processing all files\e[0m"