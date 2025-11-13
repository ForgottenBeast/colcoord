let searchActive = false;
let analyzedCount = 0;
const MODE_MAP = {
"Sf + C&K 4P" : 8,
"Sf + C&K 6P": 9,
"Cities & Knights 4P": 6,
"Cities & Knights 5-6P":7,
};

async function getPreferredModes() {
  const result = await browser.storage.local.get("preferredModes");
  // Example fallback if nothing stored yet
  return result.preferredModes ||["Sf + C&K 4P","Sf + C&K 6P","Cities & Knights 4P","Cities & Knights 5-6P"];
}

async function fetchRooms() {
  const res = await fetch("https://colonist.io/api/room-list.json");
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return await res.json(); // array of { id, mode, players, ... }
}


async function iterateRooms() {
  if (!searchActive) return;

  try {
    const [prefNames, rooms] = await Promise.all([
      getPreferredModes(),
      fetchRooms()
    ]);

    analyzedCount += rooms.length;
    browser.runtime.sendMessage({ type: "updateCount", value: analyzedCount });

    // Convert preferred mode names into their numeric equivalents
    const prefCodes = prefNames.map(name => MODE_MAP[name]).filter(Boolean);

    // Rank map: numeric code → preference rank (lower = better)
    const rank = new Map(prefCodes.map((code, i) => [code, i]));

    // Filter and sort by preference order
    const matching = rooms
      .filter(r => rank.has(r.mode))
      .sort((a, b) => rank.get(a.mode) - rank.get(b.mode));

    if (matching.length > 0) {
      const best = matching[0];
      console.log(`Top match: room ${best.id} mode=${best.mode}`, best);
      // You could notify the popup, or open the URL:
      // browser.runtime.sendMessage({ type: "matchingRooms", value: matching });
      const gameUrl = `https://colonists.io/#${best.id}`;

      console.log(`Opening top room: ${gameUrl}`);

      await browser.tabs.create({ url: gameUrl });
      searchActive = false;

    } else {
      console.log("No rooms matching preferred modes");
    }

  } catch (err) {
    console.error("Error while iterating rooms:", err);
  }

  if (searchActive) setTimeout(iterateRooms, 2000);
}


browser.runtime.onMessage.addListener((msg, sender) => {
  if (msg.type === "startSearch") {
    if (!searchActive) {
      searchActive = true;
      analyzedCount = 0;
      iterateRooms();
    }
  } else if (msg.type === "stopSearch") {
    searchActive = false;
  }
});

