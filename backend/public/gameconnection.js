import { Game } from "./localGameLogic.js";

// =================================================================
//  SOCKET CONNECTION
// =================================================================

const socket = io();
window.Game = Game;

// =================================================================
//  STATE
// =================================================================

let currentName     = "";
let currentRoom     = "";
let gameStarted     = false;
let inGame          = false;
let roomPlayerCount = 6;
let roomTeamSize    = 3;

// =================================================================
//  DOM REFERENCES
// =================================================================

const DOM = {
    // lobby
    lobbyOptions:         document.getElementById("lobbyOptions"),
    createRoomButton:     document.getElementById("createRoomButton"),
    joinRoomButton:       document.getElementById("joinRoomButton"),
    // create room form
    createRoomForm:       document.getElementById("createRoomForm"),
    createNameInput:      document.getElementById("createNameInput"),
    confirmCreateButton:  document.getElementById("confirmCreateButton"),
    backFromCreateButton: document.getElementById("backFromCreateButton"),
    // join room form
    joinForm:             document.getElementById("joinForm"),
    joinNameInput:        document.getElementById("joinNameInput"),
    roomInput:            document.getElementById("roomInput"),
    confirmJoinButton:    document.getElementById("confirmJoinButton"),
    backFromJoinButton:   document.getElementById("backFromJoinButton"),
    // room display
    roomCodeDisplay:      document.getElementById("roomCodeDisplay"),
    roomCodeText:         document.getElementById("roomCodeText"),
    // team display
    teamAList:            document.getElementById("teamAList"),
    teamBList:            document.getElementById("teamBList"),
    teamAHeader:          document.getElementById("teamAHeader"),
    teamBHeader:          document.getElementById("teamBHeader"),
    // players + game controls
    playersList:          document.getElementById("playersList"),
    playersContainer:     document.getElementById("playersContainer"),
    leaveButton:          document.getElementById("disconnectButton"),
    messagesList:         document.getElementById("messages"),
    startGameButton:      document.getElementById("startGameButton"),
    exitGameButton:       document.getElementById("exitGameButton"),
    // game panels
    gameState:            document.getElementById("gameState"),
    currentTurnBanner:    document.getElementById("currentTurnBanner"),
    lastActionMessage:    document.getElementById("lastActionMessage"),
};

// =================================================================
//  UTILITIES — used across multiple sections
// =================================================================

function addMessage(text) {
    const li = document.createElement("li");
    li.textContent = text;
    DOM.messagesList.appendChild(li);
}

function setLastAction(text) {
    DOM.lastActionMessage.innerHTML = text;
}

function getOrCreate(id, tag = "div") {
    let el = document.getElementById(id);
    if (!el) {
        el = document.createElement(tag);
        el.id = id;
        document.body.appendChild(el);
    }
    return el;
}

function syncCardCounts(cardCounts) {
    cardCounts.forEach(({ id, name, cardCount }) => {
        const player = Game.players.find(p => p.id === id);
        if (player) {
            player.cardCount = cardCount;
            if (name) player.name = name;
        }
    });
    renderTurnOrderTable(Game.teamAName, Game.teamBName);
}

// =================================================================
//  SECTION 1 — CREATE ROOM
//  UI: lobby options → create form → room code shown
//  Server: createRoom → roomCreated
// =================================================================

// ── UI ────────────────────────────────────────────────────────────

function showCreateRoomForm() {
    DOM.lobbyOptions.style.display   = "none";
    DOM.createRoomForm.style.display = "block";
}

function hideCreateRoomForm() {
    DOM.createRoomForm.style.display = "none";
    DOM.lobbyOptions.style.display   = "block";
}

function showRoomCode(code) {
    DOM.roomCodeText.textContent      = code;
    DOM.roomCodeDisplay.style.display = "block";
}

// ── Listeners ─────────────────────────────────────────────────────

DOM.createRoomButton.addEventListener("click", showCreateRoomForm);
DOM.backFromCreateButton.addEventListener("click", hideCreateRoomForm);

DOM.confirmCreateButton.addEventListener("click", () => {
    const name = DOM.createNameInput.value.trim();
    if (!name) { alert("Enter your name first"); return; }
    const formatInput = document.querySelector('input[name="gameFormat"]:checked');
    const playerCount = formatInput ? parseInt(formatInput.value) : 6;
    currentName = name;
    socket.emit("createRoom", { name, playerCount });
});

DOM.createNameInput.addEventListener("keypress", e => {
    if (e.key === "Enter") DOM.confirmCreateButton.click();
});

// ── Socket ────────────────────────────────────────────────────────

socket.on("roomCreated", ({ code, playerCount }) => {
    currentRoom     = code;
    roomPlayerCount = playerCount;
    roomTeamSize    = playerCount / 2;

    showRoomCode(code);
    DOM.lobbyOptions.style.display    = "none";
    DOM.createRoomForm.style.display  = "none";
    DOM.createNameInput.disabled      = true;
    DOM.leaveButton.style.display     = "block";
    DOM.playersContainer.style.display = "block";

    DOM.startGameButton.style.display = "block";
    DOM.startGameButton.disabled      = true;
    DOM.startGameButton.style.opacity = "0.4";
    DOM.startGameButton.title         = `Need ${roomTeamSize} players per team`;

    renderTeamPicker();
    socket.emit("getCurrentPlayers", { room: code });
});

socket.on("joinRoomError", ({ message }) => {
    alert(message);
    // ✅ Send player back to join form
    DOM.joinForm.style.display     = "block";
    DOM.lobbyOptions.style.display = "none";
    DOM.joinNameInput.disabled     = false;
    DOM.roomInput.value            = "";
});

socket.on("userNameExistError", ({ message }) => {
    alert(message);
    // ✅ Send player back to join form
    DOM.joinForm.style.display     = "block";
    DOM.lobbyOptions.style.display = "none";
    DOM.joinNameInput.disabled     = false;
    DOM.joinNameInput.value        = ""; // ✅ clear name so they can type new one
    DOM.joinNameInput.focus();          // ✅ focus name input for convenience
    // DOM.roomInput.value            = "";   // roomInput value is stored for convenience
});

socket.on("gamePaused", ({ message }) => {
    const container = document.getElementById("askCardContainer");
    if (container) {
        container.innerHTML = `
            <p style="color:#e65100; text-align:center;">⏸ ${message}</p>
        `;
    }
});

socket.on("gameResumed", ({ reason }) => {
    addMessage(`▶️ ${reason}`);

    // ✅ Clear pause message from askCardContainer for everyone
    const container = document.getElementById("askCardContainer");
    if (container) container.innerHTML = "";

    // ✅ Restore turn banner for everyone
    const currentPlayer = Game.players[Game.currentTurnIndex];
    if (currentPlayer) renderCurrentTurn(currentPlayer.name);

    // ✅ Only show turn options to the player whose turn it is
    if (inGame && Game.isMyTurn(socket.id)) {
        renderTurnOptions();
    }
});

socket.on("reconnected", ({ players, myHand, score, setsRemaining,
    teamAName, teamBName, turnOrder, currentTurn }) => {
    console.log("[GAME] Reconnected — restoring game state");

    Game.teamAName        = teamAName;
    Game.teamBName        = teamBName;
    Game.turnOrder        = turnOrder;
    Game.players          = players.map(p => ({ id: p.id, name: p.name, team: p.team, hand: [], cardCount: p.cardCount }));
    Game.teamA            = Game.players.filter(p => p.team === teamAName);
    Game.teamB            = Game.players.filter(p => p.team === teamBName);
    Game.currentTurnIndex = Game.players.findIndex(p => p.name === currentTurn);

    const me = Game.players.find(p => p.id === socket.id);
    if (me) me.hand = myHand;

    Game.startGame(currentRoom, socket);

    // ✅ Clear any pause UI
    const container = document.getElementById("askCardContainer");
    if (container) container.innerHTML = "";

    renderTurnOrderTable(teamAName, teamBName);
    renderHand(myHand);
    renderGameState(score, setsRemaining);
    renderCurrentTurn(currentTurn);

    // ✅ Show turn options if it's this player's turn
    if (me && currentTurn === me.name) renderTurnOptions();

    DOM.playersContainer.style.display  = "block";
    DOM.startGameButton.style.display   = "none";
    DOM.exitGameButton.style.display    = "block";
    DOM.exitGameButton.disabled         = false;
    gameStarted = true;
    inGame      = true;
});

socket.on("playerDisconnected", ({ playerName, paused }) => {
    addMessage(`⚠️ ${playerName} disconnected — waiting to reconnect...`);
    
    if (paused) {
        // ✅ Show pause banner
        const banner = document.getElementById("currentTurnBanner");
        if (banner) {
            banner.style.background = "#fff3e0";
            banner.style.color      = "#e65100";
            banner.textContent      = `⏸ Game paused — waiting for ${playerName} to reconnect...`;
        }

        // ✅ Disable all action buttons
        const askCardContainer = document.getElementById("askCardContainer");
        if (askCardContainer) {
            askCardContainer.innerHTML = `
                <p style="color:#e65100; text-align:center;">
                    ⏸ Game paused — waiting for <strong>${playerName}</strong> to reconnect...
                </p>
            `;
        }
    }
});

// =================================================================
//  SECTION 2 — JOIN ROOM
//  UI: lobby options → join form → enters room
//  Server: joinRoom → currentPlayers, playerJoined, roomFormat
// =================================================================

// ── UI ────────────────────────────────────────────────────────────

function showJoinRoomForm() {
    DOM.lobbyOptions.style.display = "none";
    DOM.joinForm.style.display     = "block";
}

function hideJoinRoomForm() {
    DOM.joinForm.style.display     = "none";
    DOM.lobbyOptions.style.display = "block";
}

function showPlayersContainer() {
    DOM.playersContainer.style.display = "block";
    DOM.leaveButton.style.display      = "block";
    DOM.lobbyOptions.style.display     = "none";
    DOM.createRoomForm.style.display   = "none";
    DOM.joinForm.style.display         = "none";
}

// ── Listeners ─────────────────────────────────────────────────────

DOM.joinRoomButton.addEventListener("click", showJoinRoomForm);
DOM.backFromJoinButton.addEventListener("click", hideJoinRoomForm);

DOM.confirmJoinButton.addEventListener("click", () => {
    const name = DOM.joinNameInput.value.trim();
    const room = DOM.roomInput.value.trim().toUpperCase();
    if (!name || !room) { alert("Enter name and room code"); return; }
    currentName = name;
    currentRoom = room;
    socket.emit("joinRoom", { name, room });
});

DOM.joinNameInput.addEventListener("keypress", e => {
    if (e.key === "Enter") DOM.confirmJoinButton.click();
});

DOM.roomInput.addEventListener("keypress", e => {
    if (e.key === "Enter") DOM.confirmJoinButton.click();
});

DOM.leaveButton.addEventListener("click", exitRoom);

// ── Socket ────────────────────────────────────────────────────────

socket.on("connect", () => {
    console.log(`[SOCKET] Connected — ID: ${socket.id}`);
    console.log(`[DEBUG] currentRoom: "${currentRoom}" currentName: "${currentName}" inGame: ${inGame}`);

    if (currentRoom && currentName && inGame) {
        console.log(`[SOCKET] Auto-rejoining room ${currentRoom} as ${currentName}`);
        socket.emit("joinRoom", { name: currentName, room: currentRoom });
    }
});

socket.on("disconnect", () => console.log("[SOCKET] Disconnected"));
socket.on("roomsList",  rooms => console.log("[LOBBY] rooms:", rooms));

socket.on("playerJoined", message => addMessage(message));
socket.on("playerLeft",   message => addMessage(message));

socket.on("roomFormat", ({ playerCount, teamSize }) => {
    roomPlayerCount = playerCount;
    roomTeamSize    = teamSize;

    // ✅ Show container immediately so it's ready when currentPlayers fires
    DOM.playersContainer.style.display = "block";
    DOM.leaveButton.style.display      = "block";
    DOM.lobbyOptions.style.display     = "none";
    DOM.joinForm.style.display         = "none";

    // ✅ Show start button greyed out
    DOM.startGameButton.style.display = "block";
    DOM.startGameButton.disabled      = true;
    DOM.startGameButton.style.opacity = "0.4";
    DOM.startGameButton.title         = `Need ${teamSize} players per team`;
});

// =================================================================
//  SECTION 3 — JOIN TEAM
//  UI: team picker buttons, live team A/B lists
//  Server: pickTeam → currentPlayers, teamFull
// =================================================================

// ── UI ────────────────────────────────────────────────────────────

function renderTeamPicker(teamAName = "A", teamBName = "B") {
    const container = getOrCreate("teamPickerContainer");
    container.innerHTML = `
        <h4>Pick your team:</h4>
        <button id="pickTeamA" style="margin-right:8px;">Join ${teamAName}</button>
        <button id="pickTeamB">Join ${teamBName}</button>
    `;
    document.getElementById("pickTeamA").onclick = () =>
        socket.emit("pickTeam", { room: currentRoom, team: teamAName });
    document.getElementById("pickTeamB").onclick = () =>
        socket.emit("pickTeam", { room: currentRoom, team: teamBName });
}

function renderLobbyTeams(players) {
    if (!DOM.teamAList || !DOM.teamBList) return;

    const teamA = players.filter(p => p.team === "A");
    const teamB = players.filter(p => p.team === "B");

    if (DOM.teamAHeader) DOM.teamAHeader.textContent = `Team A (${teamA.length}/${roomTeamSize})`;
    if (DOM.teamBHeader) DOM.teamBHeader.textContent = `Team B (${teamB.length}/${roomTeamSize})`;

    DOM.teamAList.innerHTML = teamA.length === 0
        ? `<li style="color:#aaa;">No players yet</li>`
        : teamA.map(p => `<li>${p.name === currentName
            ? `<strong>${p.name} (you)</strong>` : p.name}</li>`).join("");

    DOM.teamBList.innerHTML = teamB.length === 0
        ? `<li style="color:#aaa;">No players yet</li>`
        : teamB.map(p => `<li>${p.name === currentName
            ? `<strong>${p.name} (you)</strong>` : p.name}</li>`).join("");
}

// ── Socket ────────────────────────────────────────────────────────

socket.on("currentPlayers", ({ players }) => {
    
    if (DOM.playersList) {
        DOM.playersList.innerHTML = players.map(p => `
            <li>${p.name === currentName ? `<strong>${p.name} (you)</strong>` : p.name}
            ${p.team ? `— Team ${p.team}` : "— no team yet"}</li>
        `).join("");
    }
    
    renderLobbyTeams(players);

    if (!inGame) {
        const teamA = players.filter(p => p.team === "A");
        const teamB = players.filter(p => p.team === "B");
        const ready = teamA.length === roomTeamSize && teamB.length === roomTeamSize;

        DOM.startGameButton.style.display = "block";
        DOM.startGameButton.disabled      = !ready;
        DOM.startGameButton.style.opacity = ready ? "1" : "0.4";
        DOM.startGameButton.title         = ready
            ? "Start the game!"
            : `Need ${roomTeamSize} per team. A: ${teamA.length}/${roomTeamSize}, B: ${teamB.length}/${roomTeamSize}`;
    }

    const me = players.find(p => p.name === currentName);
    if (currentRoom && me && !me.team) {
        renderTeamPicker();
    } else if (me && me.team) {
        const container = getOrCreate("teamPickerContainer");
        container.innerHTML = `
            <p>✅ You are on <strong>Team ${me.team}</strong>
            <button id="changeTeamBtn" style="margin-left:8px;">Change Team</button></p>
        `;
        document.getElementById("changeTeamBtn").onclick = () =>
            socket.emit("pickTeam", { room: currentRoom, team: null });
    }

    showPlayersContainer();
});

socket.on("teamFull", ({ message }) => {
    alert(message);
    renderTeamPicker();
});

socket.on("playerCountUpdate", ({ count, playerCount }) => {
    if (inGame) return;
    roomPlayerCount = playerCount ?? roomPlayerCount;
});

// =================================================================
//  SECTION 4 — START GAME
//  UI: start button enabled when teams full
//  Server: startGame → initGame, startGameError
// =================================================================

// ── UI ────────────────────────────────────────────────────────────

function renderTurnOrderTable(teamAName, teamBName) {
    const container = getOrCreate("teamsContainer");
    if (!Game.turnOrder) return;

    const rows = Game.turnOrder.map((player, index) => {
        const isTeamA   = player.team === teamAName;
        const bgColor   = isTeamA ? "#e3f2fd" : "#fce4ec";
        const isMe      = player.id === socket.id;
        const nameLabel = isMe ? `${player.name} (you)` : player.name;
        const cardCount = Game.players.find(p => p.id === player.id)?.cardCount ?? "?";
        return `
            <tr style="background:${bgColor};">
                <td style="padding:6px 12px;">${index + 1}</td>
                <td style="padding:6px 12px; font-weight:${isMe ? "bold" : "normal"}">${nameLabel}</td>
                <td style="padding:6px 12px;">${player.team}</td>
                <td style="padding:6px 12px; text-align:right;"><strong>${cardCount}</strong> cards</td>
            </tr>
        `;
    }).join("");

    container.innerHTML = `
        <h3>Turn Order</h3>
        <table style="border-collapse:collapse; font-size:14px; width:100%;">
            <tr style="border-bottom:1px solid #ccc;">
                <th style="padding:6px 12px;">#</th>
                <th style="padding:6px 12px;">Player</th>
                <th style="padding:6px 12px;">Team</th>
                <th style="padding:6px 12px; text-align:right;">Cards</th>
            </tr>
            ${rows}
        </table>
    `;
}

function renderGameState(score, setsRemaining) {
    const container = document.getElementById("gameState");
    if (!container) return;

    const clinch = getClinchStatus(score, setsRemaining);
    container.innerHTML = `
        <table style="width:100%; border-collapse:collapse; font-size:14px;">
            <tr style="border-bottom:1px solid #eee;">
                <td style="padding:8px;">🏆 ${Game.teamAName ?? "Team A"}</td>
                <td style="padding:8px; font-weight:bold; text-align:right;">${score.teamA} pts</td>
            </tr>
            <tr style="border-bottom:1px solid #eee;">
                <td style="padding:8px;">🏆 ${Game.teamBName ?? "Team B"}</td>
                <td style="padding:8px; font-weight:bold; text-align:right;">${score.teamB} pts</td>
            </tr>
            <tr>
                <td style="padding:8px;">🂠 Sets Remaining</td>
                <td style="padding:8px; font-weight:bold; text-align:right;">${setsRemaining} / 8</td>
            </tr>
            ${clinch ? `
            <tr>
                <td colspan="2" style="padding:10px 8px; text-align:center; font-weight:bold;
                    color:#2e7d32; background:#e8f5e9; border-top:1px solid #eee;">
                    ${clinch}
                </td>
            </tr>` : ""}
        </table>
    `;
}

function getClinchStatus(score, setsRemaining) {
    if (score.teamA > score.teamB + setsRemaining) return `🏆 ${Game.teamAName} will win this match!`;
    if (score.teamB > score.teamA + setsRemaining) return `🏆 ${Game.teamBName} will win this match!`;
    return null;
}

function renderCurrentTurn(playerName) {
    const banner = document.getElementById("currentTurnBanner");
    if (!banner) return;
    const isMe = Game.players.find(p => p.id === socket.id)?.name === playerName;
    banner.style.background = isMe ? "#e8f5e9" : "#e3f2fd";
    banner.style.color      = isMe ? "#2e7d32" : "#1565c0";
    banner.textContent      = isMe ? `🟢 Your Turn — ${playerName}` : `⏳ ${playerName}'s Turn`;
}

// ── Listeners ─────────────────────────────────────────────────────

DOM.startGameButton.addEventListener("click", () => {
    if (gameStarted) return;
    socket.emit("startGame", { room: currentRoom });
    gameStarted = true;
    inGame      = true;
    DOM.startGameButton.style.display = "none";
    DOM.exitGameButton.style.display  = "block";
    DOM.exitGameButton.disabled       = false;
});

DOM.exitGameButton.addEventListener("click", () => {
    socket.emit("leaveRoom");
    gameStarted = false;
    inGame      = false;
    DOM.exitGameButton.style.display  = "none";
    DOM.startGameButton.style.display = "block";
    DOM.startGameButton.disabled      = false;
});

// ── Socket ────────────────────────────────────────────────────────

socket.on("startGameError", ({ message }) => {
    alert(message);
    gameStarted                       = false;
    inGame                            = false;
    DOM.startGameButton.disabled      = false;
    DOM.startGameButton.style.opacity = "0.4";
});

socket.on("initGame", ({ players, myHand, teamA, teamB, teamAName, teamBName,
    firstTurn, score, setsRemaining, turnOrder }) => {
    console.log("[GAME] initGame received");

    Game.teamAName        = teamAName;
    Game.teamBName        = teamBName;
    Game.turnOrder        = turnOrder;
    Game.players          = players.map(p => ({ id: p.id, name: p.name, team: p.team, hand: [], cardCount: p.cardCount }));
    Game.teamA            = Game.players.filter(p => p.team === teamAName);
    Game.teamB            = Game.players.filter(p => p.team === teamBName);
    Game.currentTurnIndex = Game.players.findIndex(p => p.name === firstTurn);

    const me = Game.players.find(p => p.id === socket.id);
    if (me) me.hand = myHand;

    Game.startGame(currentRoom, socket);

    renderTurnOrderTable(teamAName, teamBName);
    renderHand(myHand);
    renderGameState(score, setsRemaining);
    renderCurrentTurn(firstTurn);

    if (me && firstTurn === me.name) renderTurnOptions();
});

socket.on("turnChanged", ({ playerName, playerId, cardCounts }) => {
    Game.currentTurnIndex = Game.players.findIndex(p => p.id === playerId);
    renderCurrentTurn(playerName);
    if (cardCounts) syncCardCounts(cardCounts);

    if (playerId === socket.id) {
       
        renderTurnOptions();
    } else {
        const container = document.getElementById("askCardContainer");
        if (container) container.innerHTML = "";
    }
});

// =================================================================
//  SECTION 5 — ASK FOR CARD
//  UI: ask button → pick opponent → pick card → waiting
//  Server: askForCard → cardRequested → cardResponse →
//          cardResponseResult, cardTransferAnnounced,
//          cardActionSummary, turnChanged
// =================================================================

// ── UI ────────────────────────────────────────────────────────────

function renderHand(hand) {
    const container = getOrCreate("handContainer");
    container.innerHTML = "";
    hand.forEach(card => {
        const cardEl = document.createElement("div");
        cardEl.classList.add("card");
        cardEl.textContent = `${card.rank} ${card.suit}`;
        container.appendChild(cardEl);
    });
}

function renderTurnOptions() {
    if (!Game.isMyTurn(socket.id)) return;
    const me = Game.players.find(p => p.id === socket.id);
    if (!me) return;

    const container = getOrCreate("askCardContainer");
    container.innerHTML = `<h4>Your Turn — choose an action:</h4>`;

    if (me.hand.length > 0) {
        const askBtn = document.createElement("button");
        askBtn.textContent = "🃏 Ask for a Card";
        askBtn.onclick     = () => renderAskForCard();
        container.appendChild(askBtn);
    } else {
        const msg = document.createElement("p");
        msg.style.color = "gray";
        msg.textContent = "🚫 No cards in hand — you can only declare a set";
        container.appendChild(msg);
    }

    const declareBtn = document.createElement("button");
    declareBtn.textContent = "📢 Declare a Set";
    declareBtn.onclick     = () => renderDeclareSet();
    container.appendChild(declareBtn);
}

function renderAskForCard() {
    if (!Game.isMyTurn(socket.id)) return;
    const container = getOrCreate("askCardContainer");
    container.innerHTML = `<p>⏳ Loading opponents...</p>`;
    socket.emit("getEligibleOpponents", { room: currentRoom, playerId: socket.id });
}

function renderCardPicker(opponent) {
    const container = getOrCreate("askCardContainer");
    container.innerHTML = `<h4>Ask ${opponent.name} for which card?</h4>`;

    const validSets = Game.getValidSets(socket.id);
    if (validSets.length === 0) {
        container.innerHTML += `<p>No valid sets to ask from!</p>`;
        return;
    }

    validSets.forEach(set => {
        const setDiv  = document.createElement("div");
        const title   = document.createElement("p");
        title.textContent = `Set: ${set[0].rank}–${set[set.length - 1].rank} of ${set[0].suit}`;
        setDiv.appendChild(title);

        const askableCards = Game.getAskableCards(socket.id, set);
        if (askableCards.length === 0) {
            const msg = document.createElement("p");
            msg.textContent = "You have all cards in this set!";
            setDiv.appendChild(msg);
        } else {
            askableCards.forEach(card => {
                const btn = document.createElement("button");
                btn.textContent = `${card.rank}${card.suit}`;
                btn.onclick     = () => confirmAskForCard(opponent, card);
                setDiv.appendChild(btn);
            });
        }
        container.appendChild(setDiv);
    });

    const backBtn = document.createElement("button");
    backBtn.textContent = "← Back";
    backBtn.onclick     = () => renderAskForCard();
    container.appendChild(backBtn);
}

function confirmAskForCard(opponent, card) {
    socket.emit("askForCard", { room: currentRoom, fromId: socket.id, toId: opponent.id, card });
    const container = getOrCreate("askCardContainer");
    container.innerHTML = `<p>⏳ Waiting for ${opponent.name} to respond...</p>`;
}

// ── Socket ────────────────────────────────────────────────────────

socket.on("eligibleOpponents", ({ eligible }) => {
    const container = getOrCreate("askCardContainer");
    container.innerHTML = `<h4>Ask for a card — choose a player:</h4>`;

    if (eligible.length === 0) {
        const msg = document.createElement("p");
        msg.style.color = "gray";
        msg.textContent = "No opponents have cards left!";
        container.appendChild(msg);
    } else {
        eligible.forEach(opponent => {
            const btn = document.createElement("button");
            btn.textContent = opponent.name;
            btn.onclick     = () => renderCardPicker(opponent);
            container.appendChild(btn);
        });
    }

    const backBtn = document.createElement("button");
    backBtn.textContent = "← Back";
    backBtn.onclick     = () => renderTurnOptions();
    container.appendChild(backBtn);
});

socket.on("cardRequested", ({ fromId, card }) => {
    socket.emit("cardResponse", { room: currentRoom, toId: fromId, card });
});

socket.on("cardResponseResult", ({ card, hasCard, cardCounts }) => {
    if (hasCard) {
        const me = Game.players.find(p => p.id === socket.id);
        if (me) { me.hand.push(card); renderHand(me.hand); }
    }
    if (cardCounts) syncCardCounts(cardCounts);
    const container = document.getElementById("askCardContainer");
    if (container) container.innerHTML = "";
});

socket.on("cardTransferAnnounced", ({ fromName, toName, card, hasCard, cardCounts }) => {
    if (hasCard) {
        const responder = Game.players.find(p => p.name === fromName);
        if (responder) {
            // ✅ Keep this — removes card from local hand array
            responder.hand = responder.hand.filter(c =>
                !(c.suit === card.suit && c.rank === card.rank)
            );
            if (responder.id === socket.id) renderHand(responder.hand);
        }
        // ❌ Remove cardCount manual updates — syncCardCounts handles it
    }
    if (cardCounts) syncCardCounts(cardCounts); // ✅ this already updates cardCount
});

socket.on("cardActionSummary", ({ summary }) => setLastAction(summary));

socket.on("invalidAsk", ({ message }) => {
    const container = document.getElementById("askCardContainer");
    if (container) {
        const err = document.createElement("p");
        err.style.color = "red";
        err.textContent = message;
        container.prepend(err);
    }
    setTimeout(() => renderTurnOptions(), 2000);
});

// =================================================================
//  SECTION 6 — DECLARE SET
//  UI: declare button → pick set → submit / mapping UI
//  Server: declareSet → mappingRequired / declareSetResult
// =================================================================

// ── UI ────────────────────────────────────────────────────────────

function renderDeclareSet() {
    const container = getOrCreate("askCardContainer");
    container.innerHTML = `<h4>Declare a Set — choose a set:</h4>`;

    const declarableSets = Game.getValidSets(socket.id);
    if (declarableSets.length === 0) {
        const msg = document.createElement("p");
        msg.textContent = "You have no sets to declare!";
        container.appendChild(msg);
    } else {
        declarableSets.forEach(set => {
            const btn = document.createElement("button");
            btn.textContent = `${set[0].suit} ${set[0].rank} to ${set[set.length - 1].rank}`;
            btn.onclick     = () => confirmDeclareSet(set);
            container.appendChild(btn);
        });
    }

    const backBtn = document.createElement("button");
    backBtn.textContent = "← Back";
    backBtn.onclick     = () => renderTurnOptions();
    container.appendChild(backBtn);
}

function confirmDeclareSet(set) {
    socket.emit("declareSet", { room: currentRoom, playerId: socket.id, set });
    const container = getOrCreate("askCardContainer");
    container.innerHTML = `<p>⏳ Declaring set...</p>`;
}

function renderMappingUI(set, myCards, remainingCards, teammates) {
    const container = getOrCreate("askCardContainer");
    container.innerHTML = `<h4>📍 Map remaining cards to teammates:</h4>`;

    const mapping = {};

    if (myCards.length > 0) {
        const ownSection = document.createElement("div");
        ownSection.innerHTML = `<p><strong>Your cards (pre-filled):</strong></p>`;
        myCards.forEach(card => {
            const row = document.createElement("p");
            row.style.color = "gray";
            row.textContent = `${card.rank}${card.suit} — You`;
            ownSection.appendChild(row);
        });
        container.appendChild(ownSection);
    }

    const remainingSection = document.createElement("div");
    remainingSection.innerHTML = `<p><strong>Map these to a teammate:</strong></p>`;

    const submitBtn = document.createElement("button");
    submitBtn.textContent    = "✅ Submit Mapping";
    submitBtn.disabled       = true;
    submitBtn.style.marginTop = "12px";

    remainingCards.forEach(card => {
        const key = `${card.rank}${card.suit}`;
        const row = document.createElement("div");
        row.style.marginBottom = "8px";

        const label = document.createElement("span");
        label.textContent = `${card.rank}${card.suit} → `;
        row.appendChild(label);

        teammates.forEach(teammate => {
            const btn = document.createElement("button");
            btn.textContent = teammate.name;
            btn.onclick = () => {
                row.querySelectorAll("button").forEach(b => { b.style.background = ""; b.style.color = ""; });
                btn.style.background = "#4CAF50";
                btn.style.color      = "white";
                mapping[key]         = teammate.id;
                if (Object.keys(mapping).length === remainingCards.length) submitBtn.disabled = false;
            };
            row.appendChild(btn);
        });

        remainingSection.appendChild(row);
    });

    container.appendChild(remainingSection);

    submitBtn.onclick = () => {
        const mappingArray = remainingCards.map(card => ({
            card,
            teammateId: mapping[`${card.rank}${card.suit}`]
        }));
        socket.emit("submitMapping", { room: currentRoom, playerId: socket.id, mapping: mappingArray, set });
        container.innerHTML = `<p>⏳ Verifying mapping...</p>`;
    };

    container.appendChild(submitBtn);
}

// ── Socket ────────────────────────────────────────────────────────

socket.on("mappingRequired", ({ set, myCards, remainingCards, teammates }) => {
    renderMappingUI(set, myCards, remainingCards, teammates);
});

socket.on("declareSetResult", ({
    success, playerName, team, set, score, message,
    declaringTeamWon, opponentTeamWon, mappingFailed,
    nextTurn, nextTurnId, cardCounts, setsRemaining
}) => {
        const me               = Game.players.find(p => p.id === socket.id);
        const container        = document.getElementById("askCardContainer");
        const oppositeTeamName  = team === Game.teamAName ? Game.teamBName : Game.teamAName;
        const declaringTeamName = team === Game.teamAName ? Game.teamAName : Game.teamBName;
        const setLabel          = `${set[0].suit} ${set[0].rank}-${set[set.length - 1].rank}`;

        if (!success) {
            if (container) container.innerHTML = `
                <p style="color:red">❌ ${message}</p>
                <button onclick="renderDeclareSet()">← Back</button>
            `;
            return;
        }

        // ── Last action message ───────────────────────────────────────
        if (declaringTeamWon) {
            setLastAction(`${playerName} (${declaringTeamName}) declared ${setLabel}. All 6 cards held — ${declaringTeamName} gets 1 point! 🏆`);
        } else if (opponentTeamWon) {
            setLastAction(`${playerName} (${declaringTeamName}) declared ${setLabel}. ${oppositeTeamName} had a card — ${oppositeTeamName} gets 1 point! ⚡`);
        } else if (mappingFailed) {
            setLastAction(`${playerName} (${declaringTeamName}) declared ${setLabel}. Wrong mapping — no points. ❌`);
        } else {
            setLastAction(`${playerName} (${declaringTeamName}) declared ${setLabel}. Mapping correct — ${declaringTeamName} gets 1 point! ✅`);
        }

        renderGameState(score, setsRemaining);

        // ── Discard set cards from server ─────────────────────────────────
        if (cardCounts) syncCardCounts(cardCounts);

        if (me) renderHand(me.hand);
        if (cardCounts) syncCardCounts(cardCounts);

        // ── Update turn ───────────────────────────────────────────────
        Game.currentTurnIndex = Game.players.findIndex(p => p.name === nextTurn);
        renderCurrentTurn(nextTurn);

        if (nextTurnId === socket.id) {
            addMessage(`🎯 Your turn continues!`);
            renderTurnOptions();
        } else {
            addMessage(`➡️ Turn passes to ${nextTurn}`);
            if (container) container.innerHTML = "";
        }

        renderGameState(score, setsRemaining);
});

// =================================================================
//  SECTION 7 — GAME OVER
//  UI: winner/draw message shown, reset state
//  Server: gameOver
// =================================================================

function exitRoom() {
    socket.emit("leaveRoom");

    // ✅ Reset state
    currentName           = "";
    currentRoom           = "";
    gameStarted           = false;
    inGame                = false;
    roomPlayerCount       = 6;
    roomTeamSize          = 3;
    Game.players          = [];
    Game.turnOrder        = [];
    Game.teamA            = [];
    Game.teamB            = [];
    Game.teamAName        = "";
    Game.teamBName        = "";
    Game.currentTurnIndex = 0;

    // ✅ Remove dynamically created containers entirely
    ["askCardContainer", "handContainer", "turnContainer",
     "teamsContainer", "gameOverContainer",
     "teamPickerContainer", "shareContainer",
     "allPlayersContainer"].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.remove();
    });

    // ✅ Reset static panels
    DOM.lastActionMessage.innerHTML       = "No action yet";
    DOM.currentTurnBanner.textContent     = "⏳ Waiting for game to start...";
    DOM.currentTurnBanner.style.background = "#e3f2fd";
    DOM.currentTurnBanner.style.color      = "#1565c0";
    DOM.gameState.innerHTML               = "";
    DOM.teamAList.innerHTML               = "";
    DOM.teamBList.innerHTML               = "";
    DOM.messagesList.innerHTML            = "";
    DOM.playersList.innerHTML             = "";

    // ✅ Hide game/room UI
    DOM.playersContainer.style.display   = "none";
    DOM.roomCodeDisplay.style.display    = "none";
    DOM.leaveButton.style.display        = "none";
    DOM.startGameButton.style.display    = "none";
    DOM.exitGameButton.style.display     = "none";

    // ✅ Show lobby
    DOM.lobbyOptions.style.display       = "block";
    DOM.createRoomForm.style.display     = "none";
    DOM.joinForm.style.display           = "none";
    DOM.createNameInput.disabled         = false;
    DOM.joinNameInput.disabled           = false;
    DOM.roomInput.value                  = "";

    console.log("[CLIENT] Exited room — back to lobby");
}


socket.on("gameOver", ({ score, winner, draw }) => {
    ["askCardContainer", "handContainer", "turnContainer"].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.innerHTML = "";
    });

    const container = getOrCreate("gameOverContainer");
    container.style.cssText = "text-align:center; margin-top:40px;";
    container.innerHTML = draw
        ? `<h2>🤝 It's a Draw!</h2>
           <p>${Game.teamAName}: ${score.teamA} pts — ${Game.teamBName}: ${score.teamB} pts</p>`
        : `<h2>🏆 ${winner} Wins!</h2>
           <p>${Game.teamAName}: ${score.teamA} pts — ${Game.teamBName}: ${score.teamB} pts</p>`;

    // ✅ Add play again button
    const playAgainBtn = document.createElement("button");
    playAgainBtn.textContent = "🔄 Play Again";
    playAgainBtn.style.marginTop = "16px";
    playAgainBtn.onclick = () => socket.emit("playAgain", { room: currentRoom });
    container.appendChild(playAgainBtn);

    // ✅ Exit Room button
    const exitRoomBtn = document.createElement("button");
    exitRoomBtn.textContent     = "🚪 Exit Room";
    exitRoomBtn.style.marginTop = "16px";
    exitRoomBtn.onclick = () => exitRoom();
    container.appendChild(exitRoomBtn);

    gameStarted = false;
    inGame      = false;

    DOM.exitGameButton.style.display  = "none";
    DOM.startGameButton.style.display = "none"; // ✅ hide until teams re-picked
});


socket.on("playAgain", () => {
    console.log("[GAME] Play again — resetting to team selection");

    // ✅ Clear game UI
    ["askCardContainer", "handContainer", "turnContainer",
     "teamsContainer", "gameOverContainer", "gameState"].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.innerHTML = "";
    });

    // ✅ Reset client state
    gameStarted = false;
    inGame      = false;
    Game.players      = [];
    Game.turnOrder    = [];
    Game.currentTurnIndex = 0;
    Game.teamA = [];
    Game.teamB = [];

    // ✅ Reset panels
    DOM.lastActionMessage.innerHTML  = "No action yet";
    DOM.currentTurnBanner.textContent = "⏳ Waiting for game to start...";
    DOM.currentTurnBanner.style.background = "#e3f2fd";
    DOM.currentTurnBanner.style.color      = "#1565c0";

    // ✅ Show players container with team picker
    DOM.messagesList.innerHTML = "";
    DOM.playersContainer.style.display = "block";
    DOM.exitGameButton.style.display   = "none";
    DOM.startGameButton.style.display  = "block";
    DOM.startGameButton.disabled       = true;
    DOM.startGameButton.style.opacity  = "0.4";
    DOM.startGameButton.title          = `Need ${roomTeamSize} players per team`;

    // ✅ Show team picker — currentPlayers will fire from server
    // and render lobby teams + picker automatically
});


// Add temporarily at bottom of gameconnection.js
window._debug = () => ({ currentRoom, currentName, inGame, gameStarted });