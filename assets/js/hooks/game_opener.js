const GameOpener = {
  mounted() {
    this.openedWindow = null;
    this.checkInterval = null;
    this.handleEvent("open_game", ({url}) => {
      this.openedWindow = window.open(url, "_blank");
      if (!this.openedWindow) {
        this.pushEvent("popup_blocked", {url});
        return;
      }
      this.startCloseDetection();
    });
  },
  startCloseDetection() {
    this.checkInterval = setInterval(() => {
      if (this.openedWindow && this.openedWindow.closed) {
        clearInterval(this.checkInterval);
        this.pushEvent("tab_closed", {});
        this.openedWindow = null;
      }
    }, 3000);
  },
  destroyed() {
    if (this.checkInterval) clearInterval(this.checkInterval);
  }
}
export default GameOpener;
