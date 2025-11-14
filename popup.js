  const MODES_KEY = 'ext_game_modes_v3';
  const FRIENDS_KEY = 'ext_friends_v3';

  const modesList = document.getElementById('modesList');
  const friendsList = document.getElementById('friendsList');
  const friendInput = document.getElementById('friendInput');
  const addFriendBtn = document.getElementById('addFriendBtn');
  const gamesCountEl = document.getElementById('gamesCount');

  let modes = JSON.parse(localStorage.getItem(MODES_KEY) || '["Sf + C&K 4P","Sf + C&K 6P","Cities & Knights 4P","Cities & Knights 5-6P"]');
  let friends = JSON.parse(localStorage.getItem(FRIENDS_KEY) || '[]');
  let gamesAnalyzed = 0;

  function save(key, arr){ localStorage.setItem(key, JSON.stringify(arr)); }

  function renderList(listEl, items, key) {
    listEl.innerHTML = '';
    items.forEach((item, i) => {
      const li = document.createElement('li');
      li.textContent = item;
      li.dataset.index = i;
      const removeBtn = document.createElement('button');
      removeBtn.className = 'remove';
      removeBtn.textContent = '×';
      removeBtn.addEventListener('click', () => {
        items.splice(i,1);
        save(key, items);
        render();
      });
      li.appendChild(removeBtn);
      listEl.appendChild(li);
    });
  }

  function render(){
    renderList(modesList, modes, MODES_KEY);
    renderList(friendsList, friends, FRIENDS_KEY);
  }

  addFriendBtn.onclick = () => {
    const v = friendInput.value.trim();
    if(!v) return;
    friends.push(v);
    friendInput.value='';
    save(FRIENDS_KEY, friends);
    render();
  };

async function updateFromStorage() {
  const result = localStorage.getItem("gamesCount");
  const analyzedCount = result.gamesCount || 0;  // fallback to 0

  document.getElementById("gamesCount").textContent = analyzedCount;
}

browser.runtime.onMessage.addListener((msg) => {
  if (msg.type === "updateCount") {
    const counter = document.getElementById("gamesCount");
    counter.textContent = msg.value
  }
});

document.addEventListener("DOMContentLoaded", () => {
  updateFromStorage()
  const startBtn = document.getElementById('startBtn');
  const stopBtn = document.getElementById('stopBtn');
  const resetBtn = document.getElementById("resetModesBtn");

  startBtn.addEventListener('click', () => {
    console.log('Search started');
    browser.runtime.sendMessage({ type: "startSearch" });
  });

  stopBtn.addEventListener('click', () => {
    console.log('Search stopped');
    browser.runtime.sendMessage({ type: "stopSearch" });
  });
  resetBtn.addEventListener('click',() => {
    console.log("resetting modelist")
    modes = ["Sf + C&K 4P","Sf + C&K 6P","Cities & Knights 4P","Cities & Knights 5-6P"];
    render();
  });


});

  // Initial render
  render();
