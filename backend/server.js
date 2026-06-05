// =================================================================
//  server.js
// =================================================================

const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const PORT = process.env.PORT || 3000;

const {
    rooms,
    addPlayer, removePlayer, getRoomsSummary, logRooms,
    buildDeck, shuffleDeck, dealCards, getCardSet,
    randomStartTurn,
    getNextTurnAfterDeclare, getNextOpponentInTurnOrder, getEligibleOpponents,
    discardSetCards, verifyMapping,
    checkGameOver, getGameResult, generateRoomCode
} = require("./serverGameLogic");

const {
  decideBotAction,
  getBotDelay,
  createBotMemory,
  clearSetFromMemory,
  updateMemoryOnAsk,       // ← new
  updateMemoryOnTransfer,  // ← new
} = require("./botLogic");

const LOW_RANKS  = ['A', '2', '3', '4', '5', '6'];
const HIGH_RANKS = ['8', '9', '10', 'J', 'Q', 'K'];

// =================================================================
//  SERVER SETUP
// =================================================================

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    // ✅ NEW: Connection State Recovery for brief network drops
    connectionStateRecovery: {
        maxDisconnectionDuration: 2 * 60 * 1000, // 2 minutes
    },
    cors: {
        origin: process.env.ALLOWED_ORIGIN || "*",
        methods: ["GET", "POST"]
    }
});

app.use(express.static("public"));

// =================================================================
//  HELPER FUNCTIONS
// =================================================================

// ── Input validators ──────────────────────────────────────────────

function isValidString(val, maxLen = 50) {
    return typeof val === "string" && val.trim().length > 0 && val.length <= maxLen;
}

// Only allow letters, numbers, spaces, underscores, hyphens
function hasSpecialChars(val) {
    return /[^a-zA-Z0-9 _\-]/.test(val);
}

function isValidCard(card) {
    const validSuits = ["♠", "♥", "♦", "♣"];
    const validRanks = ["A", "2", "3", "4", "5", "6", "8", "9", "10", "J", "Q", "K"];
    return card &&
        typeof card === "object" &&
        validSuits.includes(card.suit) &&
        validRanks.includes(card.rank);
}

// ── Combined game action validator ───────────────────────────────

function validateGameAction(socket, room, card = null) {
    if (!isValidString(room, 6)) {
        console.warn(`[INVALID] Bad room code from socket: ${socket.id}`);
        return false;
    }
    if (card !== null && !isValidCard(card)) {
        console.warn(`[INVALID] Bad card from socket: ${socket.id}`, card);
        return false;
    }
    return true;
}

// ── Emit helpers ──────────────────────────────────────────────────

function emitCurrentPlayers(room, roomData) {
    io.to(room).emit("currentPlayers", {
        players: roomData.players.map(p => ({ name: p.name, team: p.team ?? null })),
        hostId: roomData.hostId ?? null,
        hostName: roomData.hostName ?? null
    });
}

function emitPlayerCount(room, roomData) {
    io.to(room).emit("playerCountUpdate", {
        count: roomData.players.length,
        playerCount: roomData.playerCount ?? 6
    });
}

function emitRoomsList() {
    io.emit("roomsList", getRoomsSummary());
}

function getCardCounts(roomData) {
    return roomData.players.map(p => ({ id: p.id, name: p.name, cardCount: p.hand.length }));
}

// ── Room activity tracker ─────────────────────────────────────────

function touchRoom(roomData) {
    roomData.lastActivity = Date.now();
}

// ── Guard — validate room exists and player is not rate limited ───

function getValidatedRoom(socket, roomCode) {
    const roomData = rooms[roomCode];
    if (!roomData) return null;

    if (roomData.paused) {
        console.warn(`[PAUSED] Action blocked — game is paused in room ${roomCode}`);
        socket.emit("gamePaused", {
            message: "Game is paused — waiting for disconnected player to reconnect..."
        });
        return null;
    }

    const player = roomData.players.find(p => p.id === socket.id);
    if (!player) return null;

    const now = Date.now();
    if (now - (player.lastAction ?? 0) < 500) {
        console.warn(`[RATE LIMIT] ${player.name} is sending too fast`);
        return null;
    }

    player.lastAction = now;
    touchRoom(roomData);
    return roomData;
}

// ── Turn validator ────────────────────────────────────────────────

function isPlayersTurn(socket, roomData) {
    const currentPlayer = roomData.turnOrder[roomData.currentTurnIndex];
    return currentPlayer && currentPlayer.id === socket.id;
}

// =================================================================
//  CARD RESPONSE HANDLER — shared by humans and bots
// =================================================================

function handleCardResponse(room, responderId, askerId, card, roomData) {
    const respondingPlayer = roomData.players.find(p => p.id === responderId);
    const askingPlayer = roomData.players.find(p => p.id === askerId);
    if (!respondingPlayer || !askingPlayer) return;

    const hasCard = respondingPlayer.hand.some(
        c => c.suit === card.suit && c.rank === card.rank
    );

    if (hasCard) {
        respondingPlayer.hand = respondingPlayer.hand.filter(
            c => !(c.suit === card.suit && c.rank === card.rank)
        );
        askingPlayer.hand.push(card);
    }

    const cardCounts = getCardCounts(roomData);
    const summary = hasCard
        ? `${askingPlayer.name} asked ${respondingPlayer.name} for ${card.rank}${card.suit}. ${respondingPlayer.name} had it — card transferred to ${askingPlayer.name}. Turn remains with ${askingPlayer.name}.`
        : `${askingPlayer.name} asked ${respondingPlayer.name} for ${card.rank}${card.suit}. ${respondingPlayer.name} didn't have it — turn passes to ${respondingPlayer.name}.`;

    io.to(askerId).emit("cardResponseResult", {
        fromName: respondingPlayer.name,
        card,
        hasCard,
        cardCounts
    });

    io.to(room).emit("cardTransferAnnounced", {
        fromName: respondingPlayer.name,
        toName: askingPlayer.name,
        card,
        hasCard,
        cardCounts
    });

    io.to(room).emit("cardActionSummary", { summary });

    roomData.players.forEach(player => {
        if (player.isBot && player.memory) {
            updateMemoryOnTransfer(player.memory, askingPlayer.id, respondingPlayer.id, card, hasCard);
        }
    });

    if (hasCard) {
        // ✅ Asking player got card — check if they still have cards (they should)
        io.to(room).emit("turnChanged", {
            playerName: askingPlayer.name,
            playerId: askingPlayer.id,
            cardCounts
        });
        scheduleBotTurn(room, roomData);
    } else {
        // ✅ Turn passes to responder — but check if they have cards first
        if (respondingPlayer.hand.length === 0) {
            const next = getNextPlayerWithCards(roomData);
            if (!next) {
                const { winner, draw } = getGameResult(
                    roomData.score,
                    roomData.teamAName,
                    roomData.teamBName
                );
                io.to(room).emit('gameOver', { score: roomData.score, winner, draw });
                roomData.state = 'waiting';
                return;
            }
            roomData.currentTurnIndex = next.index;
            console.log(`[GAME] ${respondingPlayer.name} has no cards — passing to ${next.player.name}`);
            io.to(room).emit('turnChanged', {
                playerName: next.player.name,
                playerId: next.player.id,
                cardCounts
            });
        } else {
            roomData.currentTurnIndex = roomData.turnOrder.findIndex(
                p => p.id === respondingPlayer.id
            );
            io.to(room).emit("turnChanged", {
                playerName: respondingPlayer.name,
                playerId: respondingPlayer.id,
                cardCounts
            });
        }
        scheduleBotTurn(room, roomData);
    }
}

// ── Declare result ────────────────────────────────────────────────

function applyDeclareResult(room, roomData, player, set, declaringTeamWon, opponentTeamWon, mappingFailed = false) {
    discardSetCards(set, roomData);
    roomData.setsRemaining = Math.max(0, roomData.setsRemaining - 1);

    const nextPlayer = (opponentTeamWon || mappingFailed)
        ? getNextOpponentInTurnOrder(player, roomData)
        : getNextTurnAfterDeclare(player, roomData);

    roomData.currentTurnIndex = roomData.turnOrder.findIndex(p => p.id === nextPlayer.id);

    const cardCounts = getCardCounts(roomData);

    // ✅ Clear declared set from all bots' memory
    roomData.players.forEach(p => {
        if (p.isBot && p.memory) {
            clearSetFromMemory(p.memory, set);
        }
    });

    io.to(room).emit("declareSetResult", {
        success: true,
        playerName: player.name,
        team: player.team,
        set,
        score: roomData.score,
        declaringTeamWon,
        opponentTeamWon,
        mappingFailed,
        nextTurn: nextPlayer.name,
        nextTurnId: nextPlayer.id,
        remainingCards: player.hand.length,
        cardCounts,
        setsRemaining: roomData.setsRemaining,
        updatedHands: roomData.players.map(p => ({ id: p.id, hand: p.hand }))
    });

    if (checkGameOver(roomData)) {
        const { winner, draw } = getGameResult(roomData.score, roomData.teamAName, roomData.teamBName);
        console.log(`[GAME] Game over — ${roomData.teamAName}:${roomData.score.teamA} ${roomData.teamBName}:${roomData.score.teamB}`);
        io.to(room).emit("gameOver", { score: roomData.score, winner, draw });
        roomData.state = "waiting";
        return;
    }

    // ✅ Check if next player has cards — if not find next with cards
    const nextFullPlayer = roomData.players.find(p => p.id === nextPlayer.id);
    if (nextFullPlayer && nextFullPlayer.hand.length === 0) {
        const next = getNextPlayerWithCards(roomData);
        if (!next) {
            const { winner, draw } = getGameResult(roomData.score, roomData.teamAName, roomData.teamBName);
            console.log(`[GAME] Game over — ${roomData.teamAName}:${roomData.score.teamA} ${roomData.teamBName}:${roomData.score.teamB}`);
            io.to(room).emit("gameOver", { score: roomData.score, winner, draw });
            roomData.state = "waiting";
            return;
        }
        roomData.currentTurnIndex = next.index;
        console.log(`[GAME] ${nextPlayer.name} has no cards — passing to ${next.player.name}`);
        io.to(room).emit('turnChanged', {
            playerName: next.player.name,
            playerId: next.player.id,
            cardCounts
        });
    }

    scheduleBotTurn(room, roomData);
}

// Find next player in turn order who still has cards
function getNextPlayerWithCards(roomData) {
  const total = roomData.turnOrder.length;
  for (let i = 1; i <= total; i++) {
    const idx = (roomData.currentTurnIndex + i) % total;
    const p = roomData.turnOrder[idx];
    const fullPlayer = roomData.players.find(fp => fp.id === p.id);
    if (fullPlayer && fullPlayer.hand.length > 0) {
      return { player: fullPlayer, index: idx };
    }
  }
  return null; // no one has cards → game over
}


// ── Bot Helper functions ─────────────────────────────────────────

const BOT_ACTION_DELAY = 1750;

function scheduleBotTurn(room, roomData) {
  setTimeout(() => executeBotTurnIfNeeded(room, roomData), BOT_ACTION_DELAY);
}

function executeBotTurn(room, roomData) {
  const currentPlayer = roomData.turnOrder[roomData.currentTurnIndex];
  if (!currentPlayer || !currentPlayer.isBot) return;

  const bot = roomData.players.find(p => p.id === currentPlayer.id);
  if (!bot) return;

  console.log(`[BOT] ${bot.name}'s turn — thinking...`);

  const delay = getBotDelay();

  setTimeout(() => {
    if (!rooms[room]) return;
    const freshRoom = rooms[room];
    const freshCurrent = freshRoom.turnOrder[freshRoom.currentTurnIndex];
    if (!freshCurrent || freshCurrent.id !== bot.id) return;
    if (freshRoom.state !== 'in-game') return;
    if (freshRoom.paused) return;

    const action = decideBotAction(bot, freshRoom);
    console.log(`[BOT] ${bot.name} decided: ${action.type}`);

    if (action.type === 'ask') {
      executeBotAsk(room, freshRoom, bot, action);
    } else if (action.type === 'declare') {
      executeBotDeclare(room, freshRoom, bot, action);
    } else if (action.type === 'noCards') {
      // ✅ Find next player with cards
      const next = getNextPlayerWithCards(freshRoom);
      if (!next) {
        // Nobody has cards — game over
        const { winner, draw } = getGameResult(
          freshRoom.score,
          freshRoom.teamAName,
          freshRoom.teamBName
        );
        io.to(room).emit('gameOver', {
          score: freshRoom.score, winner, draw
        });
        freshRoom.state = 'waiting';
        return;
      }
      // Pass turn to next player with cards
      freshRoom.currentTurnIndex = next.index;
      const cardCounts = getCardCounts(freshRoom);
      console.log(`[BOT] ${bot.name} has no cards — passing to ${next.player.name}`);
      io.to(room).emit('turnChanged', {
        playerName: next.player.name,
        playerId: next.player.id,
        cardCounts
      });
      scheduleBotTurn(room, freshRoom);
    } else {
      console.log(`[BOT] ${bot.name} skipping turn`);
    }
  }, delay);
}

// ── Bot ask card ──────────────────────────────────────────────

function executeBotAsk(room, roomData, bot, action) {
  const { toId, toName, card } = action;
  const targetPlayer = roomData.players.find(p => p.id === toId);
  if (!targetPlayer) return;

  console.log(`[BOT] ${bot.name} asks ${toName} for ${card.rank}${card.suit}`);

  // Announce the ask to all players
  io.to(room).emit('cardAskAnnounced', {
    fromName: bot.name,
    toName,
    card
  });

   roomData.players.forEach(player => {
    if (player.isBot && player.memory) {
      updateMemoryOnAsk(player.memory, bot.id, card);
    }
  });

  // Check if target has the card
  const hasCard = targetPlayer.hand.some(
    c => c.suit === card.suit && c.rank === card.rank
  );

  if (hasCard) {
    // Transfer card
    targetPlayer.hand = targetPlayer.hand.filter(
      c => !(c.suit === card.suit && c.rank === card.rank)
    );
    bot.hand.push(card);
  }
    if (bot.memory) {
    bot.memory.lastReceivedSuit = card.suit;
    bot.memory.lastReceivedIsLow = LOW_RANKS.includes(card.rank);
    }

  const cardCounts = getCardCounts(roomData);

  const summary = hasCard
    ? `${bot.name} asked ${toName} for ${card.rank}${card.suit}. ${toName} had it — card transferred to ${bot.name}. Turn remains with ${bot.name}.`
    : `${bot.name} asked ${toName} for ${card.rank}${card.suit}. ${toName} didn't have it — turn passes to ${toName}.`;

  // ✅ Update all bots' memory with transfer result
  roomData.players.forEach(player => {
    if (player.isBot && player.memory) {
      updateMemoryOnTransfer(player.memory, bot.id, targetPlayer.id, card, hasCard);
    }
  });

  io.to(room).emit('cardTransferAnnounced', {
    fromName: toName,
    toName: bot.name,
    card,
    hasCard,
    cardCounts
  });

  io.to(room).emit('cardActionSummary', { summary });

  if (hasCard) {
    // Bot keeps turn
    io.to(room).emit('turnChanged', {
      playerName: bot.name,
      playerId: bot.id,
      cardCounts
    });
    // Bot's turn again — execute after delay
    executeBotTurn(room, roomData);
  } else {
    // Turn passes to target
    roomData.currentTurnIndex = roomData.turnOrder.findIndex(
      p => p.id === targetPlayer.id
    );
    io.to(room).emit('turnChanged', {
      playerName: targetPlayer.name,
      playerId: targetPlayer.id,
      cardCounts
    });
    // Check if next player is also a bot
    scheduleBotTurn(room, roomData);
  }
}

// ── Bot declare set ───────────────────────────────────────────

function executeBotDeclare(room, roomData, bot, action) {
  const { set, mapping } = action;

  console.log(`[BOT] ${bot.name} declaring set`);

  const oppositeTeam = bot.team === roomData.teamAName
    ? roomData.teamB
    : roomData.teamA;

  // ✅ Check if opponent has any card from set
  const opponentHasCard = oppositeTeam.some(opponent =>
    opponent.hand.some(h =>
      set.some(s => s.suit === h.suit && s.rank === h.rank)
    )
  );

  let declaringTeamWon = false;
  let opponentTeamWon = false;

  if (opponentHasCard) {
    if (bot.team === roomData.teamAName) roomData.score.teamB += 1;
    else roomData.score.teamA += 1;
    opponentTeamWon = true;
    console.log(`[BOT] ${bot.name} declares — opponent had a card`);
  } else {
    // ✅ Verify mapping same as human
    const allCorrect = verifyMapping(mapping, roomData);
    console.log(`[BOT] ${bot.name} declares — ${allCorrect ? "mapping correct" : "mapping failed"}`);

    if (allCorrect) {
      if (bot.team === roomData.teamAName) roomData.score.teamA += 1;
      else roomData.score.teamB += 1;
      declaringTeamWon = true;
    } else {
      // ✅ Wrong mapping → opponent gets point
      if (bot.team === roomData.teamAName) roomData.score.teamB += 1;
      else roomData.score.teamA += 1;
      opponentTeamWon = true;
    }
  }

  discardSetCards(set, roomData);
  roomData.setsRemaining = Math.max(0, roomData.setsRemaining - 1);

  const nextPlayer = opponentTeamWon
    ? getNextOpponentInTurnOrder(bot, roomData)
    : getNextTurnAfterDeclare(bot, roomData);

  roomData.currentTurnIndex = roomData.turnOrder.findIndex(
    p => p.id === nextPlayer.id
  );

  const cardCounts = getCardCounts(roomData);

  // ✅ Clear declared set from all bots' memory
  roomData.players.forEach(player => {
    if (player.isBot && player.memory) {
      clearSetFromMemory(player.memory, set);
    }
  });

  io.to(room).emit('declareSetResult', {
    success: true,
    playerName: bot.name,
    team: bot.team,
    set,
    score: roomData.score,
    declaringTeamWon,
    opponentTeamWon,
    mappingFailed: !declaringTeamWon && !opponentTeamWon,
    nextTurn: nextPlayer.name,
    nextTurnId: nextPlayer.id,
    cardCounts,
    setsRemaining: roomData.setsRemaining,
    updatedHands: roomData.players.map(p => ({ id: p.id, hand: p.hand }))
  });

  if (checkGameOver(roomData)) {
    const { winner, draw } = getGameResult(
      roomData.score,
      roomData.teamAName,
      roomData.teamBName
    );
    io.to(room).emit('gameOver', { score: roomData.score, winner, draw });
    roomData.state = 'waiting';
    return;
  }

  // ✅ Check if next player has cards
  const nextFullPlayer = roomData.players.find(p => p.id === nextPlayer.id);
  if (nextFullPlayer && nextFullPlayer.hand.length === 0) {
    const next = getNextPlayerWithCards(roomData);
    if (!next) {
      const { winner, draw } = getGameResult(roomData.score, roomData.teamAName, roomData.teamBName);
      io.to(room).emit('gameOver', { score: roomData.score, winner, draw });
      roomData.state = 'waiting';
      return;
    }
    roomData.currentTurnIndex = next.index;
    io.to(room).emit('turnChanged', {
      playerName: next.player.name,
      playerId: next.player.id,
      cardCounts
    });
  }

  scheduleBotTurn(room, roomData);
}

// ── Check and trigger bot turn if needed ──────────────────────

function executeBotTurnIfNeeded(room, roomData) {
  const currentPlayer = roomData.turnOrder[roomData.currentTurnIndex];
  console.log(`[BOT CHECK] Current player: ${currentPlayer?.name}, isBot: ${currentPlayer?.isBot}`);
  if (currentPlayer && currentPlayer.isBot) {
    console.log(`[BOT CHECK] Triggering bot turn for ${currentPlayer.name}`);
    executeBotTurn(room, roomData);
  }
}


// =================================================================
//  SOCKET.IO
// =================================================================

io.on("connection", (socket) => {
    console.log("[SERVER] Connected:", socket.id);

    socket.onAny((event, ...args) => {
        if (process.env.NODE_ENV !== "production") {
            console.log(`[EVENT] ${event}`, JSON.stringify(args, null, 2));
        } else {
            console.log(`[EVENT] ${event} — socket: ${socket.id}`);
        }
    });

    socket.on("createRoom", ({ name, playerCount: requestedCount }) => {
        if (!isValidString(name, 8)) {
            socket.emit("createRoomError", { message: "Invalid name! Name must be between 1 and 8 characters." });
            return;
        }
        if (hasSpecialChars(name)) {
            socket.emit("createRoomError", { message: "Name can only contain letters, numbers, spaces, underscores, or hyphens." });
            return;
        }

        name = name.substring(0, 8);
        let playerCount = requestedCount === 4 ? 4 : 6;
        let code = generateRoomCode();
        while (rooms[code]) code = generateRoomCode();

        const roomData = addPlayer(socket, name, code);
        roomData.playerCount = playerCount;
        roomData.teamSize = playerCount / 2;
        roomData.lastActivity = Date.now();
        roomData.hostId = socket.id;
        roomData.hostName = name;

        console.log(`[ROOM] ${name} created room ${code} — ${playerCount} player format`);
        logRooms();

        socket.emit("roomCreated", { code, playerCount });
        emitCurrentPlayers(code, roomData);
        emitPlayerCount(code, roomData);
        io.to(code).emit("roomFormat", { playerCount, teamSize: roomData.teamSize });
        emitRoomsList();
    });

    socket.on("joinRoom", ({ name, room }) => {
        if (!isValidString(name, 8)) {
            socket.emit("joinRoomError", { message: "Invalid name! Name must be between 1 and 8 characters." });
            return;
        }
        if (hasSpecialChars(name)) {
            socket.emit("joinRoomError", { message: "Name can only contain letters, numbers, spaces, underscores, or hyphens." });
            return;
        }
        if (!isValidString(room, 6)) {
            socket.emit("joinRoomError", { message: "Invalid room code!" });
            return;
        }

        name = name.substring(0, 8);
        const existingRoom = rooms[room];

        if (!existingRoom) {
            socket.emit("joinRoomError", { message: `Room ${room} does not exist!` });
            return;
        }

        // Check if reconnecting player (works for BOTH waiting and in-game)
        if (existingRoom.disconnectedPlayers) {
            const disconnected = Object.values(existingRoom.disconnectedPlayers)
                .find(d => d.player.name === name);

            if (disconnected) {
                clearTimeout(disconnected.timeoutId);
                delete existingRoom.disconnectedPlayers[disconnected.player.id];

                const player = disconnected.player;
                const oldId = player.id;
                player.id = socket.id;
                socket.join(room);

                const turnOrderPlayer = existingRoom.turnOrder?.find(p => p.id === oldId);
                if (turnOrderPlayer) turnOrderPlayer.id = socket.id;

                if (existingRoom.state === "in-game") {
                    existingRoom.paused = false;
                    console.log(`[ROOM] ${name} reconnected to room ${room} (in-game)`);

                    socket.emit("reconnected", {
                        roomCode: room, // ✅ FIX: Echo the room code
                        players: existingRoom.players.map(p => ({ id: p.id, name: p.name, team: p.team, cardCount: p.hand.length })),
                        myHand: player.hand,
                        score: existingRoom.score,
                        setsRemaining: existingRoom.setsRemaining,
                        teamAName: existingRoom.teamAName,
                        teamBName: existingRoom.teamBName,
                        turnOrder: existingRoom.turnOrder?.map(p => ({ id: p.id, name: p.name, team: p.team })),
                        currentTurn: existingRoom.turnOrder?.[existingRoom.currentTurnIndex]?.name,
                        hostName: existingRoom.hostName ?? null
                    });

                    io.to(room).emit("playerReconnected", { playerName: name, newPlayerId: socket.id });
                    io.to(room).emit("gameResumed", {
                        reason: `${name} reconnected — game is resuming`
                    });
                    scheduleBotTurn(room, existingRoom);

                } else {
                    console.log(`[ROOM] ${name} reconnected to room ${room} (waiting)`);

                    socket.emit("waitingReconnected", {
                        roomCode: room, // ✅ FIX: Echo the room code
                        players: existingRoom.players.map(p => ({ name: p.name, team: p.team ?? null })),
                        myTeam: player.team ?? null,
                        playerCount: existingRoom.playerCount,
                        teamSize: existingRoom.teamSize,
                        hostName: existingRoom.hostName ?? null
                    });

                    io.to(room).emit("playerReconnected", { playerName: name });
                }

                emitCurrentPlayers(room, existingRoom);
                touchRoom(existingRoom);
                return;
            }
        }

        // ── Handle Play Again rejoin / Active Connection Rejoin ──
        const sameNameActive = existingRoom.players.find(
            p => p.name.toLowerCase() === name.toLowerCase()
        );

        if (sameNameActive) {
            const oldId = sameNameActive.id;
            sameNameActive.id = socket.id;
            socket.join(room);

            const turnOrderPlayer = existingRoom.turnOrder?.find(p => p.id === oldId);
            if (turnOrderPlayer) turnOrderPlayer.id = socket.id;

            if (existingRoom.hostId === oldId) {
                existingRoom.hostId = socket.id;
            }

            console.log(`[ROOM] ${name} rejoined room ${room} with new socket ID`);

            // ✅ CRITICAL BUG FIX: If the room is already in-game, send the full game state!
            if (existingRoom.state === "in-game") {
                existingRoom.paused = false;

                socket.emit("reconnected", {
                    roomCode: room, // ✅ FIX: Echo the room code
                    players: existingRoom.players.map(p => ({ id: p.id, name: p.name, team: p.team, cardCount: p.hand.length })),
                    myHand: sameNameActive.hand,
                    score: existingRoom.score,
                    setsRemaining: existingRoom.setsRemaining,
                    teamAName: existingRoom.teamAName,
                    teamBName: existingRoom.teamBName,
                    turnOrder: existingRoom.turnOrder?.map(p => ({ id: p.id, name: p.name, team: p.team })),
                    currentTurn: existingRoom.turnOrder?.[existingRoom.currentTurnIndex]?.name,
                    hostName: existingRoom.hostName ?? null
                });

                // Let others know the player is back so the game board updates
                io.to(room).emit("playerReconnected", { playerName: name, newPlayerId: socket.id });
                io.to(room).emit("gameResumed", { reason: `${name} reconnected — game is resuming` });
                scheduleBotTurn(room, existingRoom);
            } else {
                // Not in game yet, so emit waiting payload
                socket.emit('waitingReconnected', {
                    roomCode: room, // ✅ FIX: Echo the room code
                    players: existingRoom.players.map(p => ({ name: p.name, team: p.team ?? null })),
                    myTeam: sameNameActive.team ?? null,
                    playerCount: existingRoom.playerCount,
                    teamSize: existingRoom.teamSize,
                    hostName: existingRoom.hostName ?? null
                });
            }

            emitCurrentPlayers(room, existingRoom);
            touchRoom(existingRoom);
            return;
        }

        // ✅ Check duplicate name — only for new players
        const nameExists = existingRoom.players.some(
            p => p.name.toLowerCase() === name.toLowerCase()
        );
        if (nameExists) {
            socket.emit("userNameExistError", {
                message: `Name "${name}" is already taken in this room. Choose a different name.`
            });
            return;
        }

        if (existingRoom.state === "in-game") {
            socket.emit("joinRoomError", { message: `Game in room ${room} has already started!` });
            return;
        }

        const maxPlayers = existingRoom.playerCount ?? 6;
        if (existingRoom.players.length >= maxPlayers) {
            socket.emit("joinRoomError", { message: `Room ${room} is full! (${maxPlayers} players max)` });
            return;
        }

        const roomData = addPlayer(socket, name, room);
        touchRoom(roomData);

        console.log(`[ROOM] ${name} joined room ${room}`);
        logRooms();

        io.to(room).emit("playerJoined", `${name} has joined the room: ${room}`);
        emitCurrentPlayers(room, roomData);
        emitPlayerCount(room, roomData);
        socket.emit("roomFormat", {
            playerCount: roomData.playerCount ?? 6,
            teamSize: roomData.teamSize ?? 3
        });
        emitRoomsList();
    });

    socket.on("getCurrentPlayers", ({ room }) => {
        if (!validateGameAction(socket, room)) return;
        const roomData = rooms[room];
        if (!roomData) return;
        emitCurrentPlayers(room, roomData);
    });

    socket.on("leaveRoom", () => {
        const result = removePlayer(socket);
        if (!result) return;

        const { name, room } = result;
        socket.leave(room);
        logRooms();

        io.to(room).emit("playerLeft", `${name} left the room: ${room}`);
        socket.emit("playerLeft", `${name} left the room: ${room}`);

        if (rooms[room]) {
            emitCurrentPlayers(room, rooms[room]);
            emitPlayerCount(room, rooms[room]);
        }
        emitRoomsList();
    });

    socket.on("disconnect", () => {
        const roomCode = Object.keys(rooms).find(code =>
            rooms[code].players.some(p => p.id === socket.id)
        );
        if (!roomCode) return;

        const roomData = rooms[roomCode];
        const player = roomData.players.find(p => p.id === socket.id);
        if (!player) return;

        if (roomData.state === "in-game") {
            console.log(`[DISCONNECT] ${player.name} disconnected — waiting for the player to join back`);
            roomData.paused = true;

            io.to(roomCode).emit("playerDisconnected", {
                playerName: player.name,
                paused: true
            });

            const timeoutId = setTimeout(() => {
                if (!rooms[roomCode]) return;
                delete roomData.disconnectedPlayers[socket.id];
                roomData.paused = false;

                const result = removePlayer(socket);
                if (!result) return;
                console.log(`[DISCONNECT] ${player.name} removed after timeout`);
                io.to(roomCode).emit("playerLeft", `${player.name} left the game`);
                if (rooms[roomCode]) {
                    emitCurrentPlayers(roomCode, rooms[roomCode]);
                    emitPlayerCount(roomCode, rooms[roomCode]);
                }
                emitRoomsList();
            }, 30 * 60 * 1000);

            if (!roomData.disconnectedPlayers) roomData.disconnectedPlayers = {};
            roomData.disconnectedPlayers[socket.id] = { player, timeoutId };

        } else {
            console.log(`[DISCONNECT] ${player.name} disconnected from waiting room ${roomCode}`);

            if (!roomData.disconnectedPlayers) roomData.disconnectedPlayers = {};

            const timeoutId = setTimeout(() => {
                if (!rooms[roomCode]) return;
                delete roomData.disconnectedPlayers[socket.id];
                const result = removePlayer(socket);
                if (!result) return;
                console.log(`[DISCONNECT] ${player.name} removed from waiting room after timeout`);
                io.to(roomCode).emit("playerLeft", `${player.name} left the room`);
                if (rooms[roomCode]) {
                    emitCurrentPlayers(roomCode, rooms[roomCode]);
                    emitPlayerCount(roomCode, rooms[roomCode]);
                }
                emitRoomsList();
            }, 30 * 60 * 1000);

            roomData.disconnectedPlayers[socket.id] = { player, timeoutId };
            io.to(roomCode).emit("playerDisconnected", { playerName: player.name, paused: false });
        }
    });

    socket.on("pickTeam", ({ room, team }) => {
        if (!validateGameAction(socket, room)) return;
        const roomData = getValidatedRoom(socket, room);
        if (!roomData) return;

        const player = roomData.players.find(p => p.id === socket.id);
        if (!player) return;

        if (team !== null && !isValidString(team, 20)) {
            console.warn(`[INVALID] Bad team value from socket: ${socket.id}`);
            return;
        }

        if (team === null) {
            player.team = null;
            console.log(`[ROOM] ${player.name} left their team`);
            emitCurrentPlayers(room, roomData);
            return;
        }

        const teamSize = roomData.teamSize ?? 3;
        const currentCount = roomData.players.filter(p => p.team === team).length;

        if (currentCount >= teamSize) {
            socket.emit("teamFull", { message: `Team ${team} is full! (${teamSize} players max)` });
            return;
        }

        player.team = team;
        console.log(`[ROOM] ${player.name} joined team ${team}`);
        emitCurrentPlayers(room, roomData);
    });

    socket.on("startGame", ({ room, teamAName = "A", teamBName = "B" }) => {
        if (!validateGameAction(socket, room)) return;
        const roomData = getValidatedRoom(socket, room);
        if (!roomData) return;
        if (roomData.state === "in-game") return;

        if (!isValidString(teamAName, 20) || !isValidString(teamBName, 20)) {
            socket.emit("startGameError", { message: "Invalid team names!" });
            return;
        }

        const teamA = roomData.players.filter(p => p.team === teamAName);
        const teamB = roomData.players.filter(p => p.team === teamBName);
        const teamSize = roomData.teamSize ?? 3;

        if (teamA.length !== teamSize || teamB.length !== teamSize) {
            socket.emit("startGameError", {
                message: `Each team needs ${teamSize} players. ${teamAName}: ${teamA.length}/${teamSize}, ${teamBName}: ${teamB.length}/${teamSize}`
            });
            return;
        }

        roomData.teamAName = teamAName;
        roomData.teamBName = teamBName;
        roomData.teamA = teamA;
        roomData.teamB = teamB;
        roomData.state = "in-game";

        const deck = buildDeck();
        const shuffled = shuffleDeck(deck);
        const hands = dealCards(shuffled, roomData.players);
        roomData.players.forEach((player, i) => player.hand = hands[i]);

        roomData.turnOrder = [];
        for (let i = 0; i < teamA.length; i++) {
            roomData.turnOrder.push({
                ...teamA[i],
                isBot: teamA[i].isBot ?? false
            });
            roomData.turnOrder.push({
                ...teamB[i],
                isBot: teamB[i].isBot ?? false
            });
        }

        const { firstPlayer, randomIndex } = randomStartTurn(roomData.turnOrder);
        roomData.currentTurnIndex = randomIndex;

        // ✅ Initialize memory for each bot
        roomData.players.forEach(player => {
        if (player.isBot) {
            player.memory = createBotMemory();
            console.log(`[BOT MEMORY] Initialized memory for ${player.name}`);
        }
        });

        console.log(`[GAME] ${teamAName}: ${teamA.map(p => p.name)}`);
        console.log(`[GAME] ${teamBName}: ${teamB.map(p => p.name)}`);
        console.log(`[GAME] First turn: ${firstPlayer.name}`);

        roomData.players.forEach(player => {
            io.to(player.id).emit("initGame", {
                players: roomData.players.map(p => ({ id: p.id, name: p.name, team: p.team, cardCount: p.hand.length })),
                myHand: player.hand,
                teamA: teamA.map(p => p.name),
                teamB: teamB.map(p => p.name),
                firstTurn: firstPlayer.name,
                score: roomData.score,
                teamAName,
                teamBName,
                setsRemaining: roomData.setsRemaining,
                turnOrder: roomData.turnOrder.map(p => ({ id: p.id, name: p.name, team: p.team }))
            });
        });

        // ✅ If first player is a bot — trigger bot turn
       scheduleBotTurn(room, roomData);
    });

    socket.on("getEligibleOpponents", ({ room, playerId }) => {
        if (!validateGameAction(socket, room)) return;
        const roomData = getValidatedRoom(socket, room);
        if (!roomData) return;

        if (!isPlayersTurn(socket, roomData)) {
            console.warn(`[INVALID] ${socket.id} requested opponents out of turn`);
            return;
        }

        const player = roomData.players.find(p => p.id === playerId);
        if (!player) return;

        const eligible = getEligibleOpponents(player, roomData);
        io.to(playerId).emit("eligibleOpponents", { eligible });
    });

    socket.on("askForCard", ({ room, fromId, toId, card }) => {
        if (!validateGameAction(socket, room, card)) return;
        const roomData = getValidatedRoom(socket, room);
        if (!roomData) return;

        if (!isPlayersTurn(socket, roomData)) {
            io.to(fromId).emit("invalidAsk", { message: "It's not your turn!" });
            return;
        }

        const askingPlayer = roomData.players.find(p => p.id === fromId);
        const targetPlayer = roomData.players.find(p => p.id === toId);
        if (!askingPlayer || !targetPlayer) return;

        // ✅ Human has no cards — find next player with cards
        if (askingPlayer.hand.length === 0) {
            const next = getNextPlayerWithCards(roomData);
            if (!next) {
                const { winner, draw } = getGameResult(
                    roomData.score,
                    roomData.teamAName,
                    roomData.teamBName
                );
                io.to(room).emit('gameOver', { score: roomData.score, winner, draw });
                roomData.state = 'waiting';
                return;
            }
            roomData.currentTurnIndex = next.index;
            const cardCounts = getCardCounts(roomData);
            console.log(`[GAME] ${askingPlayer.name} has no cards — passing to ${next.player.name}`);
            io.to(room).emit('turnChanged', {
                playerName: next.player.name,
                playerId: next.player.id,
                cardCounts,
                declareOnly: isDeclareOnly(next.player, roomData)
            });
            scheduleBotTurn(room, roomData);
            return;
        }

        if (targetPlayer.hand.length === 0) {
            io.to(fromId).emit("invalidAsk", { message: `${targetPlayer.name} has no cards left!` });
            return;
        }

        const askedSet = getCardSet(card);
        const hasSetCard = askingPlayer.hand.some(h => askedSet.some(s => s.suit === h.suit && s.rank === h.rank));
        if (!hasSetCard) {
            io.to(fromId).emit("invalidAsk", { message: "You must have at least one card from that set!" });
            return;
        }
        if (askingPlayer.hand.some(c => c.suit === card.suit && c.rank === card.rank)) {
            io.to(fromId).emit("invalidAsk", { message: "You already have that card!" });
            return;
        }

        console.log(`[GAME] ${askingPlayer.name} asks ${targetPlayer.name} for ${card.rank}${card.suit}`);

        roomData.players.forEach(player => {
            if (player.isBot && player.memory) {
                updateMemoryOnAsk(player.memory, askingPlayer.id, card);
            }
        });

        if (targetPlayer.isBot) {
            console.log(`[BOT] Auto-responding for ${targetPlayer.name}`);
            io.to(room).emit('cardAskAnnounced', {
                fromName: askingPlayer.name,
                toName: targetPlayer.name,
                card
            });
            handleCardResponse(room, targetPlayer.id, fromId, card, roomData);
        } else {
            io.to(toId).emit("cardRequested", { fromId, fromName: askingPlayer.name, card });
            io.to(room).emit("cardAskAnnounced", { fromName: askingPlayer.name, toName: targetPlayer.name, card });
        }
    });

    socket.on("cardResponse", ({ room, toId, card }) => {
        if (!validateGameAction(socket, room, card)) return;
        const roomData = getValidatedRoom(socket, room);
        if (!roomData) return;

        // Reuse shared handler
        handleCardResponse(room, socket.id, toId, card, roomData);
    });

    socket.on("submitMapping", ({ room, playerId, mapping, set }) => {
        if (!validateGameAction(socket, room)) return;
        const roomData = getValidatedRoom(socket, room);
        if (!roomData) return;

        if (!isPlayersTurn(socket, roomData)) {
            console.warn(`[INVALID] ${socket.id} tried to declare out of turn`);
            return;
        }

        if (!Array.isArray(mapping) || !Array.isArray(set) || set.length !== 6) {
            console.warn(`[INVALID] Bad mapping/set from socket: ${socket.id}`);
            return;
        }
        if (!set.every(isValidCard)) {
            console.warn(`[INVALID] Bad card in set from socket: ${socket.id}`);
            return;
        }

        const player = roomData.players.find(p => p.id === playerId);
        if (!player) return;

        const declaringPlayerHasCard = player.hand.some(h =>
            set.some(s => s.suit === h.suit && s.rank === h.rank)
        );
        if (!declaringPlayerHasCard) {
            console.warn(`[INVALID] ${player.name} tried to declare a set they have no cards from`);
            socket.emit("declareSetResult", {
                success: false,
                message: "You must hold at least one card from a set to declare it."
            });
            return;
        }

        const oppositeTeam = player.team === roomData.teamAName
            ? roomData.teamB
            : roomData.teamA;

        const opponentHasCard = oppositeTeam.some(opponent =>
            opponent.hand.some(h => set.some(s => s.suit === h.suit && s.rank === h.rank))
        );

        if (opponentHasCard) {
            console.log(`[GAME] ${player.name} declares — case2 (opponent has a card)`);
            if (player.team === roomData.teamAName) roomData.score.teamB += 1;
            else roomData.score.teamA += 1;
            applyDeclareResult(room, roomData, player, set, false, true, false);
            return;
        }

        const allCorrect = verifyMapping(mapping, roomData);
        console.log(`[GAME] ${player.name} declares — ${allCorrect ? "mapping correct" : "mapping failed"}`);

        if (allCorrect) {
            if (player.team === roomData.teamAName) roomData.score.teamA += 1;
            else roomData.score.teamB += 1;
        }

        applyDeclareResult(room, roomData, player, set, allCorrect, false, !allCorrect);
    });

    // =================================================================
//  BOT MANAGEMENT
// =================================================================

   socket.on("addBots", ({ room }) => {
    // console.log(`[BOTS DEBUG] addBots received for room ${room}`);
    if (!validateGameAction(socket, room)) {
       // console.log(`[BOTS DEBUG] validateGameAction failed`);
        return;
    }
    const roomData = rooms[room];
    if (!roomData) {
       // console.log(`[BOTS DEBUG] roomData not found`);
        return;
    }
    // console.log(`[BOTS DEBUG] hostId: ${roomData.hostId}, socketId: ${socket.id}`);
    if (roomData.hostId !== socket.id) {
       // console.log(`[BOTS DEBUG] not host`);
        return;
    }
    // ✅ Only host can add bots
    if (roomData.hostId !== socket.id) {
        console.warn(`[BOTS] Non-host tried to add bots in room ${room}`);
        return;
    }

    // ✅ Host must have joined a team before adding bots
    const hostPlayer = roomData.players.find(p => p.id === socket.id);
    // console.log(`[BOTS DEBUG] hostPlayer: ${JSON.stringify(hostPlayer)}`);
    if (!hostPlayer || !hostPlayer.team) {
        // console.log(`[BOTS DEBUG] Host has no team — rejecting`);
        socket.emit('addBotsError', {
            message: 'You must join a team before adding bots!'
        });
        return;
    }

    const teamSize = roomData.teamSize ?? 3;
    const blueTeamName = "TEAM BLUE";
    const redTeamName = "TEAM RED";

    // Count existing bots to continue numbering
    const existingBots = roomData.players.filter(p => p.isBot);
    let botCounter = existingBots.length > 0
        ? Math.max(...existingBots.map(p => parseInt(p.name.replace('Bot ', '')))) 
        : 0;

    // Fill blue team first then red team
    const blueTeam = roomData.players.filter(p => p.team === blueTeamName);
    const redTeam = roomData.players.filter(p => p.team === redTeamName);

    const blueNeeded = teamSize - blueTeam.length;
    const redNeeded = teamSize - redTeam.length;

    // Add bots to blue team
    for (let i = 0; i < blueNeeded; i++) {
        botCounter++;
        const botName = `Bot ${botCounter}`;
        const botId = `bot_${botName.replace(' ', '_')}_${Date.now()}_${i}`;
        roomData.players.push({
        id: botId,
        name: botName,
        team: blueTeamName,
        hand: [],
        isBot: true
        });
        console.log(`[BOTS] Added ${botName} to ${blueTeamName}`);
    }

    // Add bots to red team
    for (let i = 0; i < redNeeded; i++) {
        botCounter++;
        const botName = `Bot ${botCounter}`;
        const botId = `bot_${botName.replace(' ', '_')}_${Date.now()}_${i}`;
        roomData.players.push({
        id: botId,
        name: botName,
        team: redTeamName,
        hand: [],
        isBot: true
        });
        console.log(`[BOTS] Added ${botName} to ${redTeamName}`);
    }

    console.log(`[BOTS] Room ${room} now has ${roomData.players.length} players`);
    emitCurrentPlayers(room, roomData);
    });

    socket.on("removeBot", ({ room, botName }) => {
    if (!validateGameAction(socket, room)) return;
    const roomData = getValidatedRoom(socket, room);
    if (!roomData) return;

    // Only host can remove bots
    if (roomData.hostId !== socket.id) {
        console.warn(`[BOTS] Non-host tried to remove bot in room ${room}`);
        return;
    }

    // Find and remove the bot
    const botIndex = roomData.players.findIndex(
        p => p.isBot && p.name === botName
    );

    if (botIndex === -1) {
        console.warn(`[BOTS] Bot ${botName} not found in room ${room}`);
        return;
    }

    roomData.players.splice(botIndex, 1);
    console.log(`[BOTS] Removed ${botName} from room ${room}`);
    emitCurrentPlayers(room, roomData);
    });

    socket.on("playAgain", ({ room }) => {
        if (!validateGameAction(socket, room)) return;
        const roomData = getValidatedRoom(socket, room);
        if (!roomData) return;

        roomData.state = "waiting";
        roomData.score = { teamA: 0, teamB: 0 };
        roomData.setsRemaining = 8;
        roomData.turnOrder = [];
        roomData.teamA = [];
        roomData.teamB = [];
        roomData.currentTurnIndex = 0;

        roomData.players.forEach(p => {
            p.hand = [];
            p.team = null;
        });

        console.log(`[GAME] Play again — room ${room} reset`);

        io.to(room).emit("playAgain");
        emitCurrentPlayers(room, roomData);
        emitPlayerCount(room, roomData);
    });

});

// =================================================================
//  STALE ROOM CLEANUP — runs every 10 minutes
// =================================================================

setInterval(() => {
    const now = Date.now();
    const timeout = 30 * 60 * 1000;

    Object.keys(rooms).forEach(code => {
        const room = rooms[code];
        if (!room.lastActivity) return;
        if (now - room.lastActivity > timeout) {
            delete rooms[code];
            console.log(`[CLEANUP] Deleted stale room ${code}`);
        }
    });
}, 10 * 60 * 1000);

// =================================================================
//  GLOBAL ERROR HANDLING
// =================================================================

process.on("uncaughtException", err => console.error("[UNCAUGHT EXCEPTION]", err));
process.on("unhandledRejection", err => console.error("[UNHANDLED REJECTION]", err));

// =================================================================
//  DEEP LINKING
// =================================================================

const APP_STORE_URL = 'https://apps.apple.com/app/id6761733606';
const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.nysioapps.literature';

app.get('/join', (req, res) => {
  const userAgent = req.headers['user-agent'] || '';
  const isIOS = /iPhone|iPad|iPod/i.test(userAgent);
  const isAndroid = /Android/i.test(userAgent);
  if (isIOS) {
    res.redirect(APP_STORE_URL);
  } else if (isAndroid) {
    res.redirect(PLAY_STORE_URL);
  } else {
    res.send('<html><body style="background:#0C1A10;color:white;font-family:sans-serif;text-align:center;padding:40px;"><h1>Literature</h1><p>Download the app to join</p><a href="' + APP_STORE_URL + '" style="color:#F4A76F;">App Store</a> | <a href="' + PLAY_STORE_URL + '" style="color:#7FD8C8;">Play Store</a></body></html>');
  }
});

app.get('/.well-known/apple-app-site-association', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.json({
    applinks: {
      details: [
        {
          appIDs: ['8MD7SZ7UVX.com.nysioapps.literature'],
          components: [
            {
              '/': '/join*',
              comment: 'Matches join links with room code'
            }
          ]
        }
      ]
    }
  });
});

app.get('/.well-known/assetlinks.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.json([{
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: 'com.nysioapps.literature',
      sha256_cert_fingerprints: ['EA:98:1E:F9:67:76:F1:A1:BE:8B:F7:AA:4F:79:68:2E:87:58:C0:1B:52:FE:F1:A1:0C:36:6D:02:86:FE:D4:95']
    }
  }]);
});

// =================================================================
//  START SERVER
// =================================================================
server.listen(PORT, () => console.log(`Server running on http://localhost:${PORT}`));