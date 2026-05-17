# Colcoord E2E Test Checklist

Base URL: http://homeserver/colonist

## Navigation tier

- [ ] GET / renders the page with status 200
- [ ] Page title contains "Colcoord"
- [ ] "Game Modes" section is visible
- [ ] "Friends" section is visible
- [ ] "Available Games" section is visible

## Flow tier

### Game list
- [ ] Game list renders within 5 seconds of page load (polls on connect)
- [ ] "No matching games found. Searching..." shown when no rooms match

### Mode selection
- [ ] All mode checkboxes are rendered (Base 3P, Base 4P, etc.)
- [ ] Unchecking a mode checkbox updates the game list within 4 seconds
- [ ] Re-checking the mode restores matching rooms in the list
- [ ] Mode selection persists after page reload

### Friends
- [ ] Typing a name in the "Add friend" input and submitting shows a badge
- [ ] Friend badge has a remove (×) button
- [ ] Clicking × removes the friend badge
- [ ] Friend names persist after page reload
- [ ] Rooms containing a friend are sorted to the top of the list

### Auto-join toggle
- [ ] Auto-join checkbox is unchecked by default
- [ ] Clicking the toggle checks it and shows "Searching" indicator
- [ ] Auto-join state persists after page reload

### Join button
- [ ] Each room row has a "Join" button
- [ ] Clicking "Join" attempts to open a new tab/popup for the game URL
- [ ] If popup is blocked, "Popup blocked!" alert appears with a manual link

## Regression tier

- [ ] Page renders correctly with zero rooms in the list
- [ ] Page renders correctly with friends list populated but no friends in any room
- [ ] Toggling modes rapidly (5 times in 2 seconds) does not cause visible errors
- [ ] Removing all friends one by one leaves an empty friends section (no crash)
- [ ] Auto-join toggle can be switched on and off without page errors
