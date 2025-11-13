  const MODES_KEY = 'ext_game_modes_v3';
  const FRIENDS_KEY = 'ext_friends_v3';

  const modesList = document.getElementById('modesList');
  const friendsList = document.getElementById('friendsList');
  const newModeInput = document.getElementById('newModeInput');
  const addModeBtn = document.getElementById('addModeBtn');
  const friendInput = document.getElementById('friendInput');
  const addFriendBtn = document.getElementById('addFriendBtn');
  const gamesCountEl = document.getElementById('gamesCount');

  let modes = JSON.parse(localStorage.getItem(MODES_KEY) || '["Sf + C&K 4P","Sf + C&K 6P","Cities & Knights 4P","Cities & Knights 5-6P"]');
  let friends = JSON.parse(localStorage.getItem(FRIENDS_KEY) || '[]');
  let gamesAnalyzed = 0;

  function save(key, arr){ localStorage.setItem(key, JSON.stringify(arr)); }

  function renderList(listEl, items, key, allowDrag) {
    listEl.innerHTML = '';
    items.forEach((item, i) => {
      const li = document.createElement('li');
      li.textContent = item;
      li.dataset.index = i;

      if (allowDrag) {
        li.setAttribute('draggable','true');
        li.addEventListener('dragstart', onDragStart);
        li.addEventListener('dragover', onDragOver);
        li.addEventListener('drop', onDrop);
        li.addEventListener('dragend', onDragEnd);
      }

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

  let dragSrcIndex = null;
  function onDragStart(e){ dragSrcIndex = Number(this.dataset.index); this.style.opacity='0.6'; }
  function onDragOver(e){ e.preventDefault(); this.classList.add('drag-over'); }
  function onDrop(e){
    this.classList.remove('drag-over');
    const dst = Number(this.dataset.index);
    if (dst === dragSrcIndex) return;
    const [moved] = modes.splice(dragSrcIndex,1);
    modes.splice(dst,0,moved);
    save(MODES_KEY, modes);
    render();
  }
  function onDragEnd(){ this.style.opacity='1'; document.querySelectorAll('.drag-over').forEach(el=>el.classList.remove('drag-over')); }

  function render(){
    renderList(modesList, modes, MODES_KEY, true);
    renderList(friendsList, friends, FRIENDS_KEY, false);
  }

  addModeBtn.onclick = () => {
    const v = newModeInput.value.trim();
    if(!v) return;
    modes.push(v);
    newModeInput.value='';
    save(MODES_KEY, modes);
    render();
  };

  addFriendBtn.onclick = () => {
    const v = friendInput.value.trim();
    if(!v) return;
    friends.push(v);
    friendInput.value='';
    save(FRIENDS_KEY, friends);
    render();
  };

async function updateFromStorage() {
  const result = await browser.storage.local.get("gamesCount");
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

  startBtn.addEventListener('click', () => {
    console.log('Search started');
    browser.runtime.sendMessage({ type: "startSearch" });
  });

  stopBtn.addEventListener('click', () => {
    console.log('Search stopped');
    browser.runtime.sendMessage({ type: "stopSearch" });
  });

});

  // Initial render
  render();
