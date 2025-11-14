  const MODES_KEY = 'modes';
  const FRIENDS_KEY = 'friends';

  const modesList = document.getElementById('modesList');
  const friendsList = document.getElementById('friendsList');
  const friendInput = document.getElementById('friendInput');
  const addFriendBtn = document.getElementById('addFriendBtn');
  const gamesCountEl = document.getElementById('gamesCount');

  let modes = [];
  let friends = [];
  let gamesAnalyzed = 0;

  async function loadStorage() {
  let result = await browser.storage.local.get([MODES_KEY, FRIENDS_KEY]);

  if (result[MODES_KEY]) modes = result[MODES_KEY];
  else modes = ["Sf + C&K 4P","Sf + C&K 6P","Cities & Knights 4P","Cities & Knights 5-6P"];

  if (result[FRIENDS_KEY]) friends = result[FRIENDS_KEY];
  else friends = [];
  result = await browser.storage.local.get("gamesCount");
  const analyzedCount = result.gamesCount || 0;  // fallback to 0

  document.getElementById("gamesCount").textContent = analyzedCount;

  render();
}

  function save(key, arr){ browser.storage.local.set({[key]: arr}); }

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


browser.runtime.onMessage.addListener((msg) => {
  if (msg.type === "updateCount") {
    const counter = document.getElementById("gamesCount");
    counter.textContent = msg.value
  }
});

document.addEventListener("DOMContentLoaded", () => {
  loadStorage();
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
    save(MODES_KEY,modes)
    render();
  });


});

//  render();
