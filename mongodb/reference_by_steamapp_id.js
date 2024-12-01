const steam = db.steam;
const media = db.media;
const description = db.description;
// Data preparation
steam.updateMany({}, {$unset: {description_ref: "", media_ref: "", steamspy_tags: ""}});
db.steam.aggregate([{
    $lookup: {
        from: "media", localField: "appid", foreignField: "steam_appid", as: "mediaMatch"
    }

}, {
    $lookup: {
        from: "description", localField: "appid", foreignField: "steam_appid", as: "descriptionMatch"
    }
}, {
    $addFields: {
        media_ref: {
            $arrayElemAt: ["$mediaMatch._id", 0]
        }, description_ref: {
            $arrayElemAt: ["$descriptionMatch._id", 0]
        }
    }
}, {
    $project: {
        mediaMatch: 0, descriptionMatch: 0
    }

}, {
    $merge: {
        into: "steam", whenMatched: "merge", whenNotMatched: "fail"
    }
}]);

// User creation
db.createUser({
    user: "guest", pwd: "guest", roles: [{role: "read", db: "torrent_games"}]
});

db.createView("all_properties", "steam", [{
    $lookup: {
        from: "media", localField: "media_ref", foreignField: "_id", as: "media"
    }
}, {
    $lookup: {
        from: "description", localField: "description_ref", foreignField: "_id", as: "description"
    }
}, {
    $project: {
        description_ref: 0, media_ref: 0, steam_appid: 0
    }
}]);


db.createView("properties_short_linux", "steam", [{
    $lookup: {
        from: "media", localField: "media_ref", foreignField: "_id", as: "media"
    }
}, {
    $lookup: {
        from: "description", localField: "description_ref", foreignField: "_id", as: "description"
    }
}, {
    $match: {
        platforms: {$in: ["linux"]}
    }
}, {
    $project: {
        description_ref: 0, media_ref: 0, steam_appid: 0, required_age: 0, price: 0, positive_ratings: 0, owners: 0
    }
}]);

db.createView("properties_short_linux_and_valve_publisher", "steam", [{
    $lookup: {
        from: "media", localField: "media_ref", foreignField: "_id", as: "media"
    }
}, {
    $lookup: {
        from: "description", localField: "description_ref", foreignField: "_id", as: "description"
    }
}, {
    $match: {
        platforms: {$in: ["linux"]}
    }
}, {
    $project: {
        description_ref: 0, media_ref: 0, steam_appid: 0, required_age: 0, price: 0, positive_ratings: 0, owners: 0
    }
}]);


db.createView("media_with_movies", "media", [{
    $unwind: {
        path: "$movies", preserveNullAndEmptyArrays: true
    }
}, {
    $match: {
        movies: {$ne: null}
    }
}]);

db.createView("media_with_screenshots", "media", [{
    $unwind: {
        path: "$screenshots", preserveNullAndEmptyArrays: true
    }
}, {
    $match: {
        screenshots: {$ne: null}
    }
}]);

db.getUsers()

// Functions stored on server
db.system.js.insertOne({
    _id: "isValidUrl", // Function name
    value: function (input) {
        const urlPattern = new RegExp("^(https?:\\/\\/)?" + "((([a-zA-Z0-9\\-]+\\.)+[a-zA-Z]{2,})|" + "localhost|" + "\\d{1,3}(\\.\\d{1,3}){3})" + "(\\:\\d+)?(\\/[-a-zA-Z0-9@:%._+~#=]*)*" + "(\\?[;&a-zA-Z0-9@:%_+.,~#-]*)?" + "(\\#[-a-zA-Z0-9_]*)?$", "i");
        return !!urlPattern.test(input);
    }
});

db.system.js.deleteOne({_id: "insertMedia"});

db.system.js.insertOne({
    _id: "insertMedia", value: function (appid, background, header_image, screenshots, movies) {
        if (typeof appid !== "number") {
            throw new Error("Appid must be a number");
        }
        if (typeof background !== "string") {
            throw new Error("Background must be a valid url");
        }
        if (typeof header_image !== "string") {
            throw new Error("Header image must be a valid url");
        }
        if (db.media.findOne({steam_appid: appid})) {
            console.log("Media for appid " + appid + " already exists. Skipping...");
            return;
        }
        const mediaDoc = {
            steam_appid: appid,
            background: background,
            header_image: header_image,
            screenshots: screenshots,
            movies: movies
        };
        const mediaInsertResult = db.media.insertOne(mediaDoc);
        const mediaRefId = mediaInsertResult.insertedId;
        const updateResult = db.steam.updateOne({appid: appid}, {$set: {media_ref: mediaRefId}});

        if (updateResult.matchedCount === 0) {
            throw new Error("Steam record for appid " + appid + " not found.");
        }

        console.log("Media inserted and steam record updated successfully.");
    }
});

const insertMediaFunc = db.system.js.findOne({_id: "insertMedia"}).value;
insertMedia(10, "https://cdn.cloudflare.steamstatic.com/steam/apps/10/page_bg_generated_v6b.jpg", "https://cdn.cloudflare.steamstatic.com/steam/apps/10/header.jpg", ["https://cdn.cloudflare.steamstatic.com/steam/apps/10/ss_1.jpg", "https://cdn.cloudflare.steamstatic.com/steam/apps/10/ss_2.jpg"], ["https://cdn.cloudflare.steamstatic.com/steam/apps/10/movie.294x165.jpg"]);

db.system.js.insertOne({
    _id: "checkDuplicateUrls", value: function () {
        const mediaDocs = db.media.find().toArray();
        const allUrls = [];
        mediaDocs.forEach(doc => {
            Object.values(doc).forEach(value => {
                if (value.name === "movies" || value.name === "screenshots") {
                    value.forEach(innerValue => {
                        Object.values(innerValue).forEach(innerInnerValue => {
                            if (typeof innerInnerValue === "string" && isValidUrl(innerInnerValue)) {
                                if (allUrls.includes(innerInnerValue)) {
                                    print("Duplicate url found: " + innerInnerValue);
                                } else {
                                    allUrls.push(innerInnerValue);
                                }
                            }
                        });
                    });
                }
                if (typeof value === "string" && isValidUrl(value)) {
                    if (allUrls.includes(value)) {
                        print("Duplicate url found: " + value);
                    } else {
                        allUrls.push(value);
                    }
                }
            });
        });
        return allUrls;
    }
});


db.steam.aggregate([
    {
        $match: {
            categories: { $elemMatch: { $eq: "Multi-player" } }
        }
    },
    {
        $addFields: {
            min_owners: { $toInt: { $arrayElemAt: [{ $split: ["$owners", "-"] }, 0] } }
        }
    },
    {
        $group: {
            _id: null,
            totalMinOwners: { $sum: "$min_owners" }
        }
    },
    {
        $project: {
            _id: 0,
            totalMinOwners: 1
        }
    }
], { allowDiskUse: true });

db.fs.chunks.findOne({ files_id: ObjectId("6741106a198d7ff1045d16a1"), n: 2 })