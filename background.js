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
  while (searchActive){
      try {
        const [prefNames, rooms] = await Promise.all([
          getPreferredModes(),
          fetchRooms()
        ]);

        analyzedCount += rooms["rooms"].length;
        console.log(`analyzed ${analyzedCount}`)
        await browser.storage.local.set({ "gamesCount":analyzedCount });

        const result = await browser.storage.local.get("FRIENDS_KEY");
        const friendsList = result.FRIENDS_KEY || [];
        console.log(`friends: ${friendsList}`)
        browser.runtime.sendMessage({ type: "updateCount", value: analyzedCount }).catch(() => {
        // Popup not open — ignore.
      });

        // Convert preferred mode names into their numeric equivalents
        const prefCodes = prefNames.map(name => MODE_MAP[name]).filter(Boolean);

        // Rank map: numeric code → preference rank (lower = better)
        const rank = new Map(prefCodes.map((code, i) => [code, i]));

        // Filter and sort by preference order
        const matching = rooms["rooms"]
          .filter(r => r.players.length < r.maxPlayers)
          .filter(r => rank.has(r.mode))
          .sort((a, b) => {
            // Check if any friends are in each room
            const aHasFriend = a.players.some(p => friendsList.includes(p.name));
            const bHasFriend = b.players.some(p => friendsList.includes(p.name));

            if (aHasFriend && !bHasFriend) return -1; // a first
            if (!aHasFriend && bHasFriend) return 1;  // b first

            // fallback to mode preference ranking
            return rank.get(a.mode) - rank.get(b.mode);
          });

        if (matching.length > 0) {
          const best = matching[0];
          
          const result = await browser.storage.local.get("lastGameFound");
          const lastgameId = result.lastGameFound || "None";

          if (best.id === lastgameId){
              console.log("already tried that game")
              break;
          }
          else {
              await browser.storage.local.set({ "lastGameFound":best.id });
          }
          
        
          console.log(`Top match: room ${best.id} mode=${best.mode}`, best);
          // You could notify the popup, or open the URL:
          // browser.runtime.sendMessage({ type: "matchingRooms", value: matching });
          const gameUrl = `https://colonist.io/#${best.id}`;

          console.log(`Opening top room: ${gameUrl}`);
          searchActive = false;
          console.log("stopped search")

          await browser.tabs.create({ url: gameUrl, active: true });

        } else {
          console.log("No rooms matching preferred modes");
        }

      } catch (err) {
        console.error("Error while iterating rooms:", err);
      }

      await new Promise(r => setTimeout(r, 1000)); // pause between iterations
  }
}


browser.runtime.onMessage.addListener((msg, sender) => {
  if (msg.type === "startSearch" && !searchActive) {
    searchActive = true;
    iterateRooms();
  } else if (msg.type === "stopSearch" && searchActive) {
    searchActive = false;
    analyzedCount = 0
  }
});

