// =================================================================
//  botLogic.js
//  Phase 1 — Basic bot decision making (random, as fallback)
//  Phase 2 — Card memory system (smart decisions)
// =================================================================

const {
  getCardSet,
  getEligibleOpponents,
  discardSetCards,
  verifyMapping,
} = require('./serverGameLogic');

// =================================================================
//  SECTION 1 — CONSTANTS
// =================================================================

const LOW_RANKS  = ['A', '2', '3', '4', '5', '6'];
const HIGH_RANKS = ['8', '9', '10', 'J', 'Q', 'K'];

// Timing
const BOT_DELAY_MIN = 3000;
const BOT_DELAY_MAX = 5000;

// Memory decay
const DECAY_PER_TURN    = 0.1;  // 5% decay per turn
const MEMORY_THRESHOLD  = 0.4;  // forget below 25%
const DECLARE_THRESHOLD = 0.90;  // declare if this confident
const ASK_THRESHOLD     = 0.60;  // ask if this confident
const CONFIDENT_THRESHOLD = 0.8; // Confidence threshold to directly ask for a specific card

// Starting probabilities
const PROB_CERTAIN     = 1.00;  // saw transfer/denial
const PROB_HAS_SET     = 0.90;  // asked = has set card
const PROB_ELIMINATION = 0.70;  // inferred by elimination

// Memory constraints
const MAX_MEMORY_ENTRIES = 80;

// =================================================================
//  SECTION 2 — GENERAL HELPERS
// =================================================================

function randomBetween(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomFrom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function sameCard(a, b) {
  return a.suit === b.suit && a.rank === b.rank;
}

// Get all sets bot has at least one card from
function getSetsWithCard(hand) {
  const sets = [];
  const seen = new Set();

  hand.forEach(card => {
    const setRanks = LOW_RANKS.includes(card.rank) ? LOW_RANKS : HIGH_RANKS;
    const key = `${card.suit}-${setRanks[0]}`;
    if (!seen.has(key)) {
      seen.add(key);
      sets.push({
        suit: card.suit,
        isLow: LOW_RANKS.includes(card.rank),
        ranks: setRanks,
        cards: setRanks.map(r => ({ suit: card.suit, rank: r }))
      });
    }
  });

  return sets;
}

// Cards missing from a set (bot doesn't hold them)
function getMissingCards(hand, set) {
  return set.cards.filter(
    setCard => !hand.some(h => sameCard(h, setCard))
  );
}

// Returns full player objects from opposite team with cards
function getBotEligibleOpponents(bot, roomData) {
  const oppositeTeam = bot.team === roomData.teamAName
    ? roomData.teamB
    : roomData.teamA;
  return oppositeTeam.filter(p => p.hand.length > 0);
}

// =================================================================
//  SECTION 3 — MEMORY MANAGEMENT
// =================================================================

// Creates empty memory for a bot at game start
function createBotMemory() {
  return {
    entries: []
    // Each entry:
    // {
    //   card:        { suit, rank },
    //   playerId:    string,
    //   type:        'has' | 'doesNotHave' | 'hasSetCard',
    //   probability: 0.0 - 1.0,
    //   turnsAgo:    number,
    //   source:      'transfer' | 'denial' | 'ask' | 'elimination'
    // }
  };
}

// Add or update a memory entry
// If entry already exists keep the higher probability
function addMemory(memory, card, playerId, type, probability, source) {
  const existing = memory.entries.find(e =>
    e.card.suit === card.suit &&
    e.card.rank === card.rank &&
    e.playerId === playerId &&
    e.type === type
  );

  if (existing) {
    existing.probability = Math.max(existing.probability, probability);
    existing.turnsAgo = 0;
    existing.source = source;
  } else {
    memory.entries.push({
      card,
      playerId,
      type,
      probability,
      turnsAgo: 0,
      source
    });
  }
}

// Decay all memories — called at start of each bot turn
function decayMemory(memory) {
  memory.entries.forEach(e => {
    e.turnsAgo += 1;
    e.probability = Math.max(0, e.probability - DECAY_PER_TURN);
  });

  // Remove forgotten entries
  memory.entries = memory.entries.filter(
    e => e.probability >= MEMORY_THRESHOLD
  );

  // ✅ Cap at max entries — keep highest probability ones
  if (memory.entries.length > MAX_MEMORY_ENTRIES) {
    memory.entries.sort((a, b) => b.probability - a.probability);
    memory.entries = memory.entries.slice(0, MAX_MEMORY_ENTRIES);
    console.log(`[BOT MEMORY] Capped at ${MAX_MEMORY_ENTRIES} entries`);
  }
}

// Get probability of a specific memory entry (0 if not found)
function getProbability(memory, card, playerId, type) {
  const entry = memory.entries.find(e =>
    e.card.suit === card.suit &&
    e.card.rank === card.rank &&
    e.playerId === playerId &&
    e.type === type
  );
  return entry ? entry.probability : 0;
}

// Clear all memory entries for a declared set
function clearSetFromMemory(memory, set) {
  memory.entries = memory.entries.filter(e =>
    !set.some(s => s.suit === e.card.suit && s.rank === e.card.rank)
  );
}

// Called when any player asks for a card
function updateMemoryOnAsk(memory, askerId, card) {
  // Asker doesn't have this specific card (they asked for it)
  addMemory(memory, card, askerId,
    'doesNotHave', PROB_CERTAIN, 'ask');
  // Asker has at least one card from this set (game rule)
  addMemory(memory,
    { suit: card.suit, rank: 'SET' },
    askerId, 'hasSetCard', PROB_HAS_SET, 'ask');
}

// Called when transfer result is known
function updateMemoryOnTransfer(memory, askerId, responderId, card, hasCard) {
  if (hasCard) {
    // ✅ Clear all previous 'has' entries for this card — only one player can hold it
    memory.entries = memory.entries.filter(e =>
      !(e.card.suit === card.suit && e.card.rank === card.rank && e.type === 'has')
    );

    // Asker now has the card
    addMemory(memory, card, askerId, 'has', PROB_CERTAIN, 'transfer');
    // Responder no longer has it
    addMemory(memory, card, responderId, 'doesNotHave', PROB_CERTAIN, 'transfer');
  } else {
    // Responder definitely doesn't have it
    addMemory(memory, card, responderId, 'doesNotHave', PROB_CERTAIN, 'denial');
  }
}

// =================================================================
//  SECTION 4 — DECLARE LOGIC
// =================================================================

// Declare if team collectively holds all 6 cards of a set
// Bot must hold at least one card from the set (game rule)
function findSafeDeclare(bot, roomData) {
  const hand = bot.hand;
  const setsInHand = getSetsWithCard(hand);
  const memory = bot.memory;

  const sameTeam = bot.team === roomData.teamAName
    ? roomData.teamA
    : roomData.teamB;

  const teammates = sameTeam.filter(p => p.id !== bot.id);

  for (const set of setsInHand) {

    // ── Build mapping using memory only ──────────────────────
    let canDeclare = true;
    const mapping = [];

    for (const card of set.cards) {
      // Bot holds this card itself — certain
      if (hand.some(h => sameCard(h, card))) {
        mapping.push({ card, teammateId: bot.id });
        continue;
      }

      // Check memory for confident 'has' entry from a teammate
      const memoryHolder = teammates.find(t =>
        getProbability(memory, card, t.id, 'has') >= CONFIDENT_THRESHOLD
      );

      if (memoryHolder) {
        mapping.push({ card, teammateId: memoryHolder.id });
        continue;
      }

      // ✅ Check if all opponents denied this card
      // → must be with a teammate → assign to random teammate
      const oppositeTeam = bot.team === roomData.teamAName
        ? roomData.teamB
        : roomData.teamA;

      const allOpponentsDenied = oppositeTeam.every(o =>
        getProbability(memory, card, o.id, 'doesNotHave') > 0
      );

      if (allOpponentsDenied && teammates.length > 0) {
        // Assign to teammate with highest probability or random
        const bestTeammate = teammates.reduce((best, t) => {
          const prob = getProbability(memory, card, t.id, 'has');
          const bestProb = getProbability(memory, card, best.id, 'has');
          return prob > bestProb ? t : best;
        }, teammates[0]);
        mapping.push({ card, teammateId: bestTeammate.id });
        continue;
      }

      // ❌ No confident info — cannot declare this set
      canDeclare = false;
      break;
    }

    if (canDeclare) {
      console.log(`[BOT] ${bot.name} confident to declare ${set.suit} ${set.isLow ? 'Low' : 'High'}`);
      return { set, mapping };
    }
  }

  return null;
}

// Build mapping when bot holds all 6 cards itself
function buildSelfMapping(bot, set) {
  return set.cards.map(card => ({
    card,
    teammateId: bot.id
  }));
}

// =================================================================
//  SECTION 5 — ASK CARD LOGIC
// =================================================================

// Phase 2: Find best opponent for a specific card using memory
// Falls back to random if no useful memory
function findBestOpponentForCard(card, opponents, memory) {
  if (!memory || memory.entries.length === 0) {
    return randomFrom(opponents);
  }

  const scored = opponents.map(opponent => {
    const hasProbability = getProbability(
      memory, card, opponent.id, 'has'
    );
    const doesNotHaveProbability = getProbability(
      memory, card, opponent.id, 'doesNotHave'
    );

    // Certain they don't have it
    if (doesNotHaveProbability > 0) return { opponent, score: 0 };
    // Confident they have it
    if (hasProbability >= ASK_THRESHOLD) return { opponent, score: hasProbability };
    // No strong memory — neutral
    return { opponent, score: 0.5 };
  });

  scored.sort((a, b) => b.score - a.score);

  console.log(`[BOT MEMORY] Scores for ${card.rank}${card.suit}:`,
    scored.map(s => `${s.opponent.name}:${s.score.toFixed(2)}`).join(', ')
  );

  const viable = scored.filter(s => s.score > 0);
  if (viable.length === 0) {
    console.log(`[BOT MEMORY] No viable opponents — random fallback`);
    return randomFrom(opponents);
  }

  return viable[0].opponent;
}

// Phase 2: Find best card to ask — prioritize sets closest to completion
function findBestCardToAsk(hand, opponents, memory) {
  const setsInHand = getSetsWithCard(hand);
  const askableSets = setsInHand.filter(set =>
    getMissingCards(hand, set).length > 0
  );

  if (askableSets.length === 0) return null;

  // ── Score each set ───────────────────────────────────────────────
  const scoredSets = askableSets.map(set => {
    const missing = getMissingCards(hand, set);

    const memoryScore = missing.reduce((sum, card) => {
      // Know exactly who to ask
      const hasEntry = opponents.some(o =>
        getProbability(memory, card, o.id, 'has') >= CONFIDENT_THRESHOLD
      );
      if (hasEntry) return sum + 1;

      // All opponents denied → teammate has it → declare candidate
      const allDenied = opponents.every(o =>
        getProbability(memory, card, o.id, 'doesNotHave') > 0
      );
      if (allDenied) return sum + 0.5;

      return sum + 0; // no info
    }, 0);

    // Bonus if bot just received a card from this set
    const justReceived = memory.lastReceivedSuit &&
      set.suit === memory.lastReceivedSuit &&
      set.isLow === memory.lastReceivedIsLow;

    return {
      set,
      missing,
      memoryScore: memoryScore + (justReceived ? 10 : 0)
    };
  });

  // Sort by memory score desc, then fewest missing cards
  scoredSets.sort((a, b) =>
    b.memoryScore !== a.memoryScore
      ? b.memoryScore - a.memoryScore
      : a.missing.length - b.missing.length
  );

  console.log(`[BOT MEMORY] Set scores:`,
    scoredSets.map(s =>
      `${s.set.suit}${s.set.isLow ? 'Low' : 'High'}:${s.memoryScore.toFixed(1)}`
    ).join(', ')
  );

  // ── Priority 1: High confidence 'has' entry ─────────────────────
  const confidentEntries = memory.entries
    .filter(e => e.type === 'has' && e.probability >= CONFIDENT_THRESHOLD)
    .sort((a, b) => {
      if (b.probability !== a.probability) return b.probability - a.probability;
      return Math.random() - 0.5; // random tiebreaker
    });

  for (const entry of confidentEntries) {
    const card = entry.card;
    const opponent = opponents.find(o => o.id === entry.playerId);
    if (!opponent) continue;

    const botAlreadyHas = hand.some(h => sameCard(h, card));
    if (botAlreadyHas) continue;

    const setRanks = LOW_RANKS.includes(card.rank) ? LOW_RANKS : HIGH_RANKS;
    const cardSet = setRanks.map(r => ({ suit: card.suit, rank: r }));
    const botHasSetCard = hand.some(h => cardSet.some(c => sameCard(h, c)));
    if (!botHasSetCard) continue;

    console.log(`[BOT MEMORY] Priority 1 — confident hit: ${card.rank}${card.suit} with ${opponent.name} (p=${entry.probability.toFixed(2)})`);
    return { card, opponent };
  }

  // ── Priority 2: Best scored set ─────────────────────────────────
  for (const { set, missing } of scoredSets) {
    // Shuffle so ask order is unpredictable when probabilities are equal
    const shuffledMissing = [...missing].sort(() => Math.random() - 0.5);

    for (const card of shuffledMissing) {
      // Skip cards where all opponents denied — teammate has it
      const allDenied = opponents.every(o =>
        getProbability(memory, card, o.id, 'doesNotHave') > 0
      );
      if (allDenied) continue;

      const viableOpponents = opponents.filter(o =>
        getProbability(memory, card, o.id, 'doesNotHave') === 0
      );
      if (viableOpponents.length > 0) {
        const bestOpponent = findBestOpponentForCard(card, viableOpponents, memory);
        console.log(`[BOT MEMORY] Priority 2 — best set: ${card.rank}${card.suit} with ${bestOpponent.name}`);
        return { card, opponent: bestOpponent };
      }
    }
  }

  // ── Priority 3: Absolute fallback ───────────────────────────────
  console.log(`[BOT MEMORY] Priority 3 — random fallback`);
  const chosenSet = randomFrom(askableSets);
  const missingCards = getMissingCards(hand, chosenSet);
  return {
    card: randomFrom(missingCards),
    opponent: randomFrom(opponents)
  };
}

// Main ask function — uses memory if available, random as fallback
function pickCardToAsk(bot, roomData) {
  const hand = bot.hand;
  const opponents = getBotEligibleOpponents(bot, roomData);

  if (opponents.length === 0) {
    console.log(`[BOT] ${bot.name} has no eligible opponents`);
    return null;
  }

  const memory = bot.memory;

  // Phase 2 — memory based
  if (memory && memory.entries.length > 0) {
    console.log(`[BOT MEMORY] ${bot.name} using memory to pick card`);
    const result = findBestCardToAsk(hand, opponents, memory);
    if (result) {
      console.log(`[BOT] ${bot.name} asks ${result.opponent.name} for ${result.card.rank}${result.card.suit}`);
      return result;
    }
  }

  // Phase 1 fallback — random
  console.log(`[BOT] ${bot.name} using random fallback`);
  const setsInHand = getSetsWithCard(hand);
  const askableSets = setsInHand.filter(set =>
    getMissingCards(hand, set).length > 0
  );

  if (askableSets.length === 0) {
    console.log(`[BOT] ${bot.name} has no askable sets`);
    return null;
  }

  const chosenSet      = randomFrom(askableSets);
  const missingCards   = getMissingCards(hand, chosenSet);
  const chosenCard     = randomFrom(missingCards);
  const chosenOpponent = randomFrom(opponents);

  console.log(`[BOT] ${bot.name} asks ${chosenOpponent.name} for ${chosenCard.rank}${chosenCard.suit} (random)`);

  return { opponent: chosenOpponent, card: chosenCard };
}
// =================================================================
//  SECTION 6 — MAIN DECISION
// =================================================================

function decideBotAction(bot, roomData) {
  const hand = bot.hand;

  if (bot.memory) {
    decayMemory(bot.memory);
    console.log(`[BOT MEMORY] Decayed memory for ${bot.name}, entries remaining: ${bot.memory.entries.length}`);
  }

  if (hand.length === 0) {
    console.log(`[BOT] ${bot.name} has no cards — passing turn`);
    return { type: 'noCards' };
  }

  const oppositeTeam = bot.team === roomData.teamAName
    ? roomData.teamB
    : roomData.teamA;
  const oppositeHasCards = oppositeTeam.some(p => p.hand.length > 0);

  if (!oppositeHasCards) {
    console.log(`[BOT] ${bot.name} in declare-only mode`);
    const declarable = findSafeDeclare(bot, roomData);
    if (declarable) {
      return {
        type: 'declare',
        set: declarable.set.cards,
        mapping: declarable.mapping
      };
    }
    console.log(`[BOT] ${bot.name} — no declarable set`);
    return { type: 'noCards' };
  }

  // Normal flow — try declare first
  const declarable = findSafeDeclare(bot, roomData);
  if (declarable) {
    return {
      type: 'declare',
      set: declarable.set.cards,
      mapping: declarable.mapping
    };
  }

  // Otherwise ask for a card
  const askAction = pickCardToAsk(bot, roomData);
  if (!askAction) {
    return { type: 'skip' };
  }

  return {
    type: 'ask',
    toId:   askAction.opponent.id,
    toName: askAction.opponent.name,
    card:   askAction.card
  };
}
// =================================================================
//  SECTION 7 — TIMING
// =================================================================

function getBotDelay() {
  return randomBetween(BOT_DELAY_MIN, BOT_DELAY_MAX);
}

// =================================================================
//  EXPORTS
// =================================================================

module.exports = {
  decideBotAction,
  getBotDelay,
  createBotMemory,
  addMemory,
  decayMemory,
  getProbability,
  clearSetFromMemory,
  updateMemoryOnAsk,
  updateMemoryOnTransfer,
};