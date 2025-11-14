const MODES_KEY = 'modes';
const FRIENDS_KEY = 'friends';
let searchActive = false;
let analyzedCount = 0;
const MODE_MAP = {
"Sf + C&K 4P" : 8,
"Sf + C&K 6P": 9,
"Cities & Knights 4P": 6,
"Cities & Knights 5-6P":7,
};

async function getPreferredModes() {
  const result = await browser.storage.local.get(MODES_KEY);
  // Example fallback if nothing stored yet
  return result[MODES_KEY] || ["Sf + C&K 4P","Sf + C&K 6P","Cities & Knights 4P","Cities & Knights 5-6P"];
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


        console.log(`prefmodes: ${prefNames}`);
        analyzedCount += rooms["rooms"].length;
        console.log(`analyzed ${analyzedCount}`)
        await browser.storage.local.set({ "gamesCount":analyzedCount });

        const result = await browser.storage.local.get(FRIENDS_KEY);
        const friendsList = result[FRIENDS_KEY] || [];
        console.log(`friends: ${friendsList}`);
        browser.runtime.sendMessage({ type: "updateCount", value: analyzedCount }).catch(() => {
        // Popup not open — ignore.
  });

        // Convert preferred mode names into their numeric equivalents
        const prefCodes = prefNames.map(name => MODE_MAP[name]).filter(Boolean);
        console.log(`got prefcodes ${prefCodes}`)

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
        for (const room of matching) {
            if (room.id === lastgameId) {
              console.log("Already tried that game:", room.id);
              continue; // skip to next matching room
            }

            // Save this room as the last tried
            await browser.storage.local.set({ lastGameFound: room.id });

            console.log(`Matching room: ${room.id} mode=${room.mode}`, room);
            const gameUrl = `https://colonist.io/#${room.id}`;
            console.log(`Opening room: ${gameUrl}`);

            searchActive = false; // stop search after opening one room
            await browser.tabs.create({ url: gameUrl, active: true });

            break; // stop after opening the first new room
          }
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

