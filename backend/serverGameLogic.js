// =================================================================
//  serverGameLogic.js
// =================================================================

// =================================================================
//  DATA
// =================================================================

const rooms = {};

// =================================================================
//  SECTION 1 — ROOM MANAGEMENT
//  generateRoomCode, addPlayer, removePlayer,
//  getRoomsSummary, logRooms
// =================================================================

function generateRoomCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no confusing chars like 0,O,1,I
    let code = "";
    for (let i = 0; i < 4; i++) {
        code += chars[Math.floor(Math.random() * chars.length)];
    }
    return code;
}

function addPlayer(socket, name, roomCode) {
    socket.join(roomCode);

    if (!rooms[roomCode]) {
        rooms[roomCode] = {
            players:          [],
            teamA:            [],
            teamB:            [],
            teamAName:        "A",
            teamBName:        "B",
            currentTurnIndex: 0,
            state:            "waiting",
            score:            { teamA: 0, teamB: 0 },
            setsRemaining:    8
        };
    }

    const room   = rooms[roomCode];
    const exists = room.players.some(p => p.id === socket.id);

    // ✅ Hard limit — don't exceed playerCount
    const maxPlayers = room.playerCount ?? 6;
    if (!exists && room.players.length >= maxPlayers) return room;
    if (!exists) room.players.push({ id: socket.id, name });

    return room;
}

function removePlayer(socket) {
    for (const roomCode in rooms) {
        const room  = rooms[roomCode];
        const index = room.players.findIndex(p => p.id === socket.id);

        if (index !== -1) {
            const player = room.players.splice(index, 1)[0];
            if (room.players.length === 0) delete rooms[roomCode];
            socket.leave(roomCode);
            return { name: player.name, room: roomCode };
        }
    }
    return null;
}

function getRoomsSummary() {
    return Object.entries(rooms).map(([code, room]) => ({
        code,
        players: room.players.length,
        state:   room.state
    }));
}

function logRooms() {
    console.log("[ROOMS]", JSON.stringify(
        Object.entries(rooms).map(([code, r]) => ({
            code,
            players: r.players.map(p => p.name),
            state:   r.state
        })),
        null, 2
    ));
}

// =================================================================
//  SECTION 2 — DECK
//  buildDeck, shuffleDeck, dealCards, getCardSet
// =================================================================

function buildDeck() {
    const suits     = ["♠", "♥", "♦", "♣"];
    const lowRanks  = ["A", "2", "3", "4", "5", "6"];
    const highRanks = ["8", "9", "10", "J", "Q", "K"];
    const ranks     = [...lowRanks, ...highRanks];
    const deck      = [];

    for (const suit of suits)
        for (const rank of ranks)
            deck.push({ suit, rank });

    return deck; // 48 cards total (no 7s)
}

function shuffleDeck(deck) {
    const d = [...deck];
    for (let i = d.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [d[i], d[j]] = [d[j], d[i]];
    }
    return d;
}

function dealCards(deck, players) {
    const handSize = Math.floor(deck.length / players.length);
    return players.map((_, i) => deck.slice(i * handSize, (i + 1) * handSize));
}

function getCardSet(card) {
    const lowRanks  = ["A", "2", "3", "4", "5", "6"];
    const highRanks = ["8", "9", "10", "J", "Q", "K"];
    const ranks     = lowRanks.includes(card.rank) ? lowRanks : highRanks;
    return ranks.map(rank => ({ suit: card.suit, rank }));
}

// =================================================================
//  SECTION 3 — TEAMS & TURNS
//  divideTeams, randomStartTurn,
//  getNextTurnAfterDeclare, getNextOpponentInTurnOrder,
//  getEligibleOpponents
// =================================================================

function divideTeams(players, teamAName = "A", teamBName = "B") {
    const shuffled = [...players].sort(() => Math.random() - 0.5);
    const teamSize = players.length / 2;
    const teamA    = shuffled.slice(0, teamSize);
    const teamB    = shuffled.slice(teamSize);

    teamA.forEach(p => p.team = teamAName);
    teamB.forEach(p => p.team = teamBName);

    return { teamA, teamB };
}

function randomStartTurn(players) {
    const randomIndex = Math.floor(Math.random() * players.length);
    const firstPlayer = players[randomIndex];
    console.log(`[GAME] First turn: ${firstPlayer.name}`);
    return { firstPlayer, randomIndex };
}

function getNextTurnAfterDeclare(player, roomData) {
    const turnOrder    = roomData.turnOrder;
    const currentIndex = turnOrder.findIndex(p => p.id === player.id);

    // 1. Player still has cards — stay with them
    if (player.hand.length > 0) return player;

    // 2. Hand empty — find next teammate in turnOrder
    for (let i = 1; i <= turnOrder.length; i++) {
        const next = turnOrder[(currentIndex + i) % turnOrder.length];
        if (next.team === player.team && next.hand.length > 0) {
            console.log(`[GAME] Next teammate: ${next.name}`);
            return next;
        }
    }

    // 3. No teammates have cards — find next anyone with cards
    for (let i = 1; i <= turnOrder.length; i++) {
        const next = turnOrder[(currentIndex + i) % turnOrder.length];
        if (next.hand.length > 0) {
            console.log(`[GAME] No teammates left — next: ${next.name}`);
            return next;
        }
    }

    // 4. Nobody has cards — game should be over
    return player;
}

function getNextOpponentInTurnOrder(player, roomData) {
    const turnOrder    = roomData.turnOrder;
    const currentIndex = turnOrder.findIndex(p => p.id === player.id);

    // Walk forward until finding an opponent with cards
    for (let i = 1; i <= turnOrder.length; i++) {
        const next = turnOrder[(currentIndex + i) % turnOrder.length];
        if (next.team !== player.team && next.hand.length > 0) {
            console.log(`[GAME] Next opponent: ${next.name}`);
            return next;
        }
    }

    // Fallback — no opponent has cards, pick anyone
    const anyPlayer = roomData.players.find(p => p.hand.length > 0);
    console.log(`[GAME] Fallback next turn: ${anyPlayer?.name}`);
    return anyPlayer || player;
}

function getEligibleOpponents(player, roomData) {
    const oppositeTeam = player.team === roomData.teamAName
        ? roomData.teamB
        : roomData.teamA;

    return oppositeTeam
        .filter(p => p.hand.length > 0)
        .map(p => ({ id: p.id, name: p.name }));
}

// =================================================================
//  SECTION 4 — DECLARE LOGIC
//  discardSetCards, getDeclareCase,
//  buildMappingPayload, verifyMapping
// =================================================================

function discardSetCards(set, roomData) {
    roomData.players.forEach(p => {
        p.hand = p.hand.filter(handCard =>
            !set.some(s => s.suit === handCard.suit && s.rank === handCard.rank)
        );
    });
    console.log(`[GAME] Set discarded from all players`);
}

function verifyMapping(mapping, roomData) {
    return mapping.every(({ card, teammateId }) => {
        const teammate = roomData.players.find(p => p.id === teammateId);
        return teammate?.hand.some(h => h.suit === card.suit && h.rank === card.rank) ?? false;
    });
}

// =================================================================
//  SECTION 5 — GAME OVER
//  checkGameOver, getGameResult
// =================================================================

function checkGameOver(roomData) {
    const totalCards = roomData.players.reduce((sum, p) => sum + p.hand.length, 0);
    return totalCards === 0;
}

function getGameResult(score, teamAName = "A", teamBName = "B") {
    if (score.teamA > score.teamB) return { winner: teamAName, draw: false };
    if (score.teamB > score.teamA) return { winner: teamBName, draw: false };
    return { winner: null, draw: true };
}

// =================================================================
//  EXPORTS
// =================================================================

module.exports = {
    // data
    rooms,
    // room management
    generateRoomCode,
    addPlayer,
    removePlayer,
    getRoomsSummary,
    logRooms,
    // deck
    buildDeck,
    shuffleDeck,
    dealCards,
    getCardSet,
    // teams & turns
    divideTeams,
    randomStartTurn,
    getNextTurnAfterDeclare,
    getNextOpponentInTurnOrder,
    getEligibleOpponents,
    // declare logic
    discardSetCards,
    verifyMapping,
    // game over
    checkGameOver,
    getGameResult,
};