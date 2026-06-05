// =================================================================
//  localGameLogic.js
//  Client-side game state and logic
// =================================================================

export const Game = {

    // =================================================================
    //  SECTION 1 — STATE
    //  All shared game state variables
    // =================================================================

    players:          [],
    sets:             [],
    teamA:            [],
    teamB:            [],
    teamAName:        "A",
    teamBName:        "B",
    turnOrder:        [],
    currentTurnIndex: 0,
    socket:           null,

    // Card definitions — matches server deck (no 7s)
    suits:     ["♠", "♥", "♦", "♣"],
    lowRanks:  ["A", "2", "3", "4", "5", "6"],
    highRanks: ["8", "9", "10", "J", "Q", "K"],

    // =================================================================
    //  SECTION 2 — SETUP
    //  startGame, initSets
    // =================================================================

    startGame(room, socket) {
        console.log(`[GAME] Starting game in room ${room}`);
        this.socket = socket;
        this.initSets();
        console.log(`[GAME] ${this.sets.length} sets initialized`);
    },

    initSets() {
        this.sets = [];

        // 4 low sets (A-6) + 4 high sets (8-K) = 8 sets total
        for (const suit of this.suits) {
            this.sets.push(this.lowRanks.map(rank  => ({ suit, rank })));
            this.sets.push(this.highRanks.map(rank => ({ suit, rank })));
        }
    },

    // =================================================================
    //  SECTION 3 — TURN
    //  isMyTurn
    // =================================================================

    isMyTurn(socketId) {
        const current = this.players[this.currentTurnIndex];
        if (!current) return false;
        return current.id === socketId;
    },

    // =================================================================
    //  SECTION 4 — HAND QUERIES
    //  getValidSets, getAskableCards, getCardSet
    // =================================================================

    // Sets where player has at least 1 card
    // Used for both asking and declaring
    getValidSets(socketId) {
        const player = this.players.find(p => p.id === socketId);
        if (!player) {
            console.warn("[GAME] getValidSets — player not found:", socketId);
            return [];
        }

        return this.sets.filter(set =>
            set.some(setCard =>
                player.hand.some(h => h.suit === setCard.suit && h.rank === setCard.rank)
            )
        );
    },

    // Cards from a set that the player does NOT already hold
    // Used to build the ask card UI
    getAskableCards(socketId, set) {
        const player = this.players.find(p => p.id === socketId);
        if (!player) {
            console.warn("[GAME] getAskableCards — player not found:", socketId);
            return [];
        }

        return set.filter(setCard =>
            !player.hand.some(h => h.suit === setCard.suit && h.rank === setCard.rank)
        );
    },

    // Find which set a card belongs to (low or high)
    getCardSet(card) {
        const ranks = this.lowRanks.includes(card.rank)
            ? this.lowRanks
            : this.highRanks;
        return ranks.map(rank => ({ suit: card.suit, rank }));
    },

    // =================================================================
    //  SECTION 5 — ACTIONS
    //  Client-side validation before emitting to server
    //  askForCard
    // =================================================================

    // Validates ask is legal before emitting to server
    // Returns true if valid, false if not
    askForCard(targetPlayer, card, socket) {
        const me = this.players.find(p => p.id === socket.id);
        if (!me) {
            console.warn("[GAME] askForCard — player not found:", socket.id);
            return false;
        }

        if (me.team === targetPlayer.team) {
            console.warn("[GAME] askForCard — cannot ask a teammate!");
            return false;
        }

        const alreadyHas = me.hand.some(h => h.suit === card.suit && h.rank === card.rank);
        if (alreadyHas) {
            console.warn("[GAME] askForCard — player already has this card!");
            return false;
        }

        const hasSetCard = this.getCardSet(card).some(setCard =>
            me.hand.some(h => h.suit === setCard.suit && h.rank === setCard.rank)
        );
        if (!hasSetCard) {
            console.warn("[GAME] askForCard — player has no card from this set!");
            return false;
        }

        console.log(`[GAME] ${me.name} asking ${targetPlayer.name} for ${card.rank}${card.suit}`);
        return true;
    },

};