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
      take: 40 // Increased to show more from both sources
    });

    return res.json(events);
  } catch (err) {
    console.error("getUpcomingEvents error:", err.message);
    return res.status(500).json({ message: "Server error" });
  }
};

/**
 * Scrapes upcoming events from multiple sources and syncs them to the database
 */
exports.syncEventsFromSource = async () => {
  console.log("🔄 Starting multi-source event synchronization...");

  let totalSynced = 0;

  // 1. Sync Istanbul
  totalSynced += await syncKulturIstanbul();

  // 2. Sync Ankara
  totalSynced += await syncAnkaraBelTr();

  console.log(`✅ Total successfully synced ${totalSynced} events from all sources.`);
};

/**
 * Helper: Sync Istanbul events (Kültür İstanbul)
 */
async function syncKulturIstanbul() {
  console.log("  [Istanbul] Fetching events...");
  try {
    const url = "https://kultur.istanbul/em-ajax/get_listings/";
    const headers = {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      "X-Requested-With": "XMLHttpRequest"
    };

    let page = 1;
    let maxPages = 1;
    let syncedCount = 0;

    while (page <= maxPages) {
      const formData = new URLSearchParams();
      formData.append("page", page.toString());
      formData.append("per_page", "24");
      formData.append("orderby", "featured");
      formData.append("order", "DESC");
      formData.append("show_pagination", "true");

      const { data: jsonData } = await axios.post(url, formData, { headers, timeout: 15000 });

      if (page === 1) {
        maxPages = jsonData.max_num_pages || 1;
        if (maxPages > 3) maxPages = 3; // Limit for performance
      }

      const htmlContent = jsonData.html || "";
      if (!htmlContent.trim()) break;

      const $ = cheerio.load(htmlContent);
      const events = $(".wpem-event-layout-wrapper");

      const scrapePromises = [];

      events.each((i, el) => {
        const title = $(el).find("h3.wpem-heading-text").text().trim();
        const link = $(el).find("a.wpem-event-action-url").attr("href") || "";
        const rawDate = $(el).find("div.wpem-event-date-time").text().trim();
        const dateMatch = rawDate.match(/\d{2}-\d{2}-\d{4}/);
        const date = dateMatch ? dateMatch[0] : (rawDate.split(/\s+/)[0] || "N/A");
        const location = $(el).find("div.wpem-event-location").text().trim() || "N/A";
        const category = $(el).find(".wpem-event-category").text().trim() || "Etkinlik";
        const imageUrl = $(el).find(".wpem-event-banner-img img").attr("src") || "";

        if (title) {
          const externalId = `ist-${title}-${date}`.toLowerCase().replace(/[^a-z0-9]/g, "-");
          scrapePromises.push(upsertEvent(externalId, title, date, location, category, imageUrl, link));
          syncedCount++;
        }
      });

      await Promise.all(scrapePromises);
      page++;
      if (page > 5) break;
    }
    console.log(`  [Istanbul] Synced ${syncedCount} events.`);
    return syncedCount;
  } catch (err) {
    console.error("  [Istanbul] Sync error:", err.message);
    return 0;
  }
}

/**
 * Helper: Sync Ankara events (Ankara Bel Tr)
 */
async function syncAnkaraBelTr() {
  console.log("  [Ankara] Fetching events...");
  try {
    const url = "https://www.ankara.bel.tr/etkinlikler";
    const headers = {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    };

    const { data } = await axios.get(url, { headers, timeout: 15000 });
    const $ = cheerio.load(data);
    const events = $("a.event-list-item");

    let syncedCount = 0;
    const scrapePromises = [];

    const monthMap = {
      'ocak': '01', 'şubat': '02', 'subat': '02', 'mart': '03', 'nisan': '04',
      'mayıs': '05', 'mayis': '05', 'haziran': '06', 'temmuz': '07',
      'ağustos': '08', 'agustos': '08', 'eylül': '09', 'eylul': '09',
      'ekim': '10', 'kasım': '11', 'kasim': '11', 'aralık': '12', 'aralik': '12'
    };

    events.each((i, el) => {
      const link = 'https://www.ankara.bel.tr' + ($(el).attr('href') || '');
      const info = $(el).find('.info');
      if (!info.length) return;

      const title = info.find('strong').text().trim() || 'N/A';
      let rawDate = 'N/A';
      let location = 'N/A';

      info.find('div').each((_, div) => {
        const hasCalendar = $(div).find('i.fa-calendar, i.fal.fa-calendar').length > 0;
        const hasLocation = $(div).find('i.fa-location-dot, i.fal.fa-location-dot').length > 0;

        if (hasCalendar) {
          rawDate = $(div).find('span').text().trim();
        } else if (hasLocation) {
          location = $(div).find('span').text().trim();
        }
      });

      // Parse date to DD-MM-YYYY
      let date = rawDate;
      if (rawDate !== 'N/A') {
        const parts = rawDate.split(/\s+/);
        if (parts.length >= 3) {
          const day = parts[0].padStart(2, '0');
          const monthStr = parts[1].toLowerCase();
          const year = parts[2];
          const month = monthMap[monthStr] || '00';
          if (month !== '00') {
            date = `${day}-${month}-${year}`;
          }
        }
      }

      if (title !== 'N/A') {
        const externalId = `ank-${title}-${date}`.toLowerCase().replace(/[^a-z0-9]/g, "-");
        scrapePromises.push(upsertEvent(externalId, title, date, location, "Etkinlik", "", link));
        syncedCount++;
      }
    });

    await Promise.all(scrapePromises);
    console.log(`  [Ankara] Synced ${syncedCount} events.`);
    return syncedCount;
  } catch (err) {
    console.error("  [Ankara] Sync error:", err.message);
    return 0;
  }
}

/**
 * Common Upsert Logic
 */
async function upsertEvent(externalId, title, date, location, category, imageUrl, link) {
  return prisma.event.upsert({
    where: { externalId },
    update: {
      title,
      date,
      location,
      category,
      imageUrl,
      link,
      updatedAt: new Date()
    },
    create: {
      externalId,
      title,
      date,
      location,
      category,
      imageUrl,
      link
    }
  });
}
