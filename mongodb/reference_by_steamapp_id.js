const description = db.description;
const media = db.media;

description.find().forEach(
    record => {
        const mediaRecord = media.findOne({steam_appid: record.steam_appid});
        if (mediaRecord) {
            console.log(`Found description record ${record.steam_appid} with media record ${mediaRecord.steam_appid}`);
        }
    }
);

description.aggregate([
    {
        $lookup: {
            from: "media",          // Target collection
            localField: "media_ref",     // Reference field in `collection1`
            foreignField: "_id",         // Matching `_id` in `collection2`
            as: "media"           // Field to store the result
        }
    }])