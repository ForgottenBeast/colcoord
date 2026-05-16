--------------------------- MODULE game_finder ---------------------------
(**************************************************************************)
(* TLA+ specification of the GameFinder state machine from colcoord.      *)
(* Models the browser extension that polls colonist.io for matching game  *)
(* rooms, opens a tab, and resumes search if the tab is closed early.     *)
(**************************************************************************)

EXTENDS Naturals, FiniteSets

CONSTANTS
    GameIds,        \* Set of possible game IDs
    ModeCodes,      \* Set of all mode codes (e.g. {6, 7, 8, 9})
    Usernames       \* Set of possible usernames

VARIABLES
    searchState,    \* "idle" | "polling" | "match_found" | "tab_opened" | "resuming"
    autoJoin,       \* Boolean: whether auto-join is enabled
    tabOpenedAt,    \* Nat (timestamp) or 0 (representing None)
    lastGameFound,  \* GameId or "None"
    rooms,          \* Subset of [id: GameIds, mode: ModeCodes] (available rooms)
    selectedModes,  \* Subset of ModeCodes (user's preferred modes)
    friends,        \* Subset of Usernames
    clock           \* Abstract clock for modeling elapsed time

vars == <<searchState, autoJoin, tabOpenedAt, lastGameFound, rooms, selectedModes, friends, clock>>

-----------------------------------------------------------------------------
(* Type invariant *)

TypeOK ==
    /\ searchState \in {"idle", "polling", "match_found", "tab_opened", "resuming"}
    /\ autoJoin \in BOOLEAN
    /\ tabOpenedAt \in Nat
    /\ lastGameFound \in GameIds \cup {"None"}
    /\ rooms \subseteq [id: GameIds, mode: ModeCodes]
    /\ selectedModes \subseteq ModeCodes
    /\ friends \subseteq Usernames
    /\ clock \in Nat

-----------------------------------------------------------------------------
(* Initial state *)

Init ==
    /\ searchState = "idle"
    /\ autoJoin \in BOOLEAN
    /\ tabOpenedAt = 0
    /\ lastGameFound = "None"
    /\ rooms \in SUBSET [id: GameIds, mode: ModeCodes]
    /\ selectedModes \in (SUBSET ModeCodes \ {{}})
    /\ friends \in SUBSET Usernames
    /\ clock = 0

-----------------------------------------------------------------------------
(* Helper: rooms that match the user's criteria and skip lastGameFound *)

MatchingRooms ==
    {r \in rooms : r.mode \in selectedModes /\ r.id /= lastGameFound}

-----------------------------------------------------------------------------
(* Actions *)

(* StartSearch: Idle -> Polling *)
(* Triggered by user clicking start or autoJoin being enabled *)
StartSearch ==
    /\ searchState = "idle"
    /\ autoJoin = TRUE
    /\ searchState' = "polling"
    /\ UNCHANGED <<autoJoin, tabOpenedAt, lastGameFound, rooms, selectedModes, friends, clock>>

ManualStartSearch ==
    /\ searchState = "idle"
    /\ searchState' = "polling"
    /\ UNCHANGED <<autoJoin, tabOpenedAt, lastGameFound, rooms, selectedModes, friends, clock>>

(* PollTick (no match): Polling -> Polling *)
(* The environment may change the available rooms between polls *)
PollTickNoMatch ==
    /\ searchState = "polling"
    /\ \E newRooms \in SUBSET [id: GameIds, mode: ModeCodes] :
        /\ rooms' = newRooms
        /\ LET matching == {r \in newRooms : r.mode \in selectedModes /\ r.id /= lastGameFound}
           IN Cardinality(matching) = 0
    /\ searchState' = "polling"
    /\ clock' = clock + 1
    /\ UNCHANGED <<autoJoin, tabOpenedAt, lastGameFound, selectedModes, friends>>

(* PollTick (match found): Polling -> MatchFound *)
PollTickMatch ==
    /\ searchState = "polling"
    /\ \E newRooms \in SUBSET [id: GameIds, mode: ModeCodes] :
        /\ rooms' = newRooms
        /\ LET matching == {r \in newRooms : r.mode \in selectedModes /\ r.id /= lastGameFound}
           IN Cardinality(matching) > 0
    /\ searchState' = "match_found"
    /\ clock' = clock + 1
    /\ UNCHANGED <<autoJoin, tabOpenedAt, lastGameFound, selectedModes, friends>>

(* OpenTab: MatchFound -> TabOpened *)
(* Pick a matching room, record its ID, open a tab *)
OpenTab ==
    /\ searchState = "match_found"
    /\ \E r \in MatchingRooms :
        /\ lastGameFound' = r.id
    /\ tabOpenedAt' = clock
    /\ searchState' = "tab_opened"
    /\ UNCHANGED <<autoJoin, rooms, selectedModes, friends, clock>>

(* TabClosedEarly: TabOpened -> Resuming (elapsed < 30s, modeled as clock - tabOpenedAt < 2) *)
(* We use an abstract threshold of 2 clock ticks to represent 30 seconds *)
TabClosedEarly ==
    /\ searchState = "tab_opened"
    /\ tabOpenedAt /= 0
    /\ clock - tabOpenedAt < 2
    /\ searchState' = "resuming"
    /\ UNCHANGED <<autoJoin, tabOpenedAt, lastGameFound, rooms, selectedModes, friends, clock>>

(* TabClosedLate: TabOpened -> Idle (elapsed >= 30s) *)
TabClosedLate ==
    /\ searchState = "tab_opened"
    /\ tabOpenedAt /= 0
    /\ clock - tabOpenedAt >= 2
    /\ searchState' = "idle"
    /\ tabOpenedAt' = 0
    /\ UNCHANGED <<autoJoin, lastGameFound, rooms, selectedModes, friends, clock>>

(* Resume: Resuming -> Polling *)
(* Clears tabOpenedAt, keeps lastGameFound so the same game is skipped *)
Resume ==
    /\ searchState = "resuming"
    /\ tabOpenedAt' = 0
    /\ searchState' = "polling"
    /\ UNCHANGED <<autoJoin, lastGameFound, rooms, selectedModes, friends, clock>>

(* StopSearch: Any active state -> Idle *)
StopSearch ==
    /\ searchState \in {"polling", "match_found", "tab_opened", "resuming"}
    /\ searchState' = "idle"
    /\ tabOpenedAt' = 0
    /\ UNCHANGED <<autoJoin, lastGameFound, rooms, selectedModes, friends, clock>>

(* Tick: advance the clock while a tab is open *)
Tick ==
    /\ searchState = "tab_opened"
    /\ clock' = clock + 1
    /\ UNCHANGED <<searchState, autoJoin, tabOpenedAt, lastGameFound, rooms, selectedModes, friends>>

-----------------------------------------------------------------------------
(* Next-state relation *)

Next ==
    \/ StartSearch
    \/ ManualStartSearch
    \/ PollTickNoMatch
    \/ PollTickMatch
    \/ OpenTab
    \/ TabClosedEarly
    \/ TabClosedLate
    \/ Resume
    \/ StopSearch
    \/ Tick

Spec == Init /\ [][Next]_vars

FairSpec == Init /\ [][Next]_vars
    /\ WF_vars(PollTickMatch)
    /\ WF_vars(PollTickNoMatch)
    /\ WF_vars(OpenTab)
    /\ WF_vars(Resume)
    /\ WF_vars(Tick)

-----------------------------------------------------------------------------
(* Safety invariants *)

(* If a tab is open, tabOpenedAt must be set *)
TabOpenedImpliesTimestamp ==
    searchState = "tab_opened" => tabOpenedAt /= 0

(* Only one tab open at a time — enforced by the state machine itself:
   we can only be in tab_opened once, and must leave before opening another *)
SingleTab ==
    searchState = "tab_opened" => lastGameFound /= "None"

(* lastGameFound is skipped in filtering — ensured by MatchingRooms definition *)
(* Verified structurally: MatchingRooms excludes lastGameFound *)

-----------------------------------------------------------------------------
(* Temporal (liveness) properties — checked under FairSpec *)

(* If a match is found, eventually a tab is opened *)
MatchLeadsToTab ==
    searchState = "match_found" ~> searchState = "tab_opened"

(* If a tab is closed early (resuming), eventually search resumes polling *)
EarlyCloseResumes ==
    searchState = "resuming" ~> searchState = "polling"

(* Liveness: if matching rooms exist, eventually a match is found *)
(* This requires fairness on PollTickMatch *)
EventualMatch ==
    (searchState = "polling" /\ Cardinality(MatchingRooms) > 0) ~> searchState = "match_found"

=============================================================================
