const axios = require("axios");
const cheerio = require("cheerio");
const prisma = require("../src/prisma");

/**
 * Fetches events from the database (Very fast)
 */
exports.getUpcomingEvents = async (req, res) => {
  try {
    const events = await prisma.event.findMany({
      orderBy: { id: "asc" },
      take: 20
    });

    return res.json(events);
  } catch (err) {
    console.error("getUpcomingEvents error:", err.message);
    return res.status(500).json({ message: "Server error" });
  }
};

/**
 * Scrapes upcoming events and syncs them to the database
 * This can be called by a cron job or manually.
 */
exports.syncEventsFromSource = async () => {
  console.log("🔄 Starting event synchronization...");
  try {
    const targetUrl = "https://kultur.istanbul/etkinlikler/";

    const { data } = await axios.get(targetUrl, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      },
      timeout: 10000
    });

    const $ = cheerio.load(data);
    let syncedCount = 0;

    const scrapePromises = [];

    $(".etkinlik-card").each((i, el) => {
      if (i >= 20) return; // Sync top 20 events

      const title = $(el).find(".etkinlik-title").text().trim();
      const date = $(el).find(".etkinlik-date").text().trim();
      const location = $(el).find(".etkinlik-place").text().trim();
      const category = $(el).find(".etkinlik-category").text().trim() || "Etkinlik";
      const imageUrl = $(el).find(".etkinlik-img img").attr("src") || "";
      const link = $(el).find("a").attr("href") || "";

      if (title) {
        // Use a combination of title and date as an externalId to avoid duplicates
        const externalId = `${title}-${date}`.toLowerCase().replace(/[^a-z0-9]/g, "-");

        scrapePromises.push(
          prisma.event.upsert({
            where: { externalId },
            update: {
              title,
              date,
              location,
              category,
              imageUrl: imageUrl.startsWith("http") ? imageUrl : `https://kultur.istanbul${imageUrl}`,
              link: link.startsWith("http") ? link : `https://kultur.istanbul${link}`,
              updatedAt: new Date()
            },
            create: {
              externalId,
              title,
              date,
              location,
              category,
              imageUrl: imageUrl.startsWith("http") ? imageUrl : `https://kultur.istanbul${imageUrl}`,
              link: link.startsWith("http") ? link : `https://kultur.istanbul${link}`
            }
          })
        );
        syncedCount++;
      }
    });

    await Promise.all(scrapePromises);
    console.log(`✅ Successfully synced ${syncedCount} events from Kültür İstanbul.`);

    // Optional: Clean up very old events that weren't updated in the last sync
    // await prisma.event.deleteMany({ where: { updatedAt: { lt: new Date(Date.now() - 1000 * 60 * 60) } } });

  } catch (err) {
    console.error("❌ Event sync error:", err.message);
  }
};
