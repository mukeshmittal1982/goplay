/**
 * Generates a single elimination bracket for N players.
 * @param {number} tournamentId - The ID of the tournament.
 * @param {Array<number>} playerIds - Array of player IDs registered.
 * @returns {Array<Object>} - List of match objects to be inserted into the DB.
 */
function generateSingleEliminationDraw(tournamentId, playerIds) {
  const n = playerIds.length;
  if (n < 2) throw new Error('At least 2 players are required for a tournament.');

  // 1. Shuffle players for random draw
  const shuffledPlayers = [...playerIds].sort(() => Math.random() - 0.5);

  // 2. Calculate P (next power of 2)
  const p = Math.pow(2, Math.ceil(Math.log2(n)));
  const numByes = p - n;

  const matches = [];
  let matchIndex = 0;

  // Round 1 Matches
  // Total matches in Round 1 = p / 2
  for (let i = 0; i < p / 2; i++) {
    const p1 = shuffledPlayers[i * 2] || null;
    const p2 = shuffledPlayers[i * 2 + 1] || null;

    matches.push({
      tournament_id: tournamentId,
      round: 1,
      match_index: ++matchIndex,
      player1_id: p1,
      player2_id: p2,
      status: (p1 && p2) ? 'PENDING' : 'FINISHED', // If one is null (Bye), match is finished
      winner_id: (p1 && !p2) ? p1 : (p2 && !p1) ? p2 : null,
      score_text: (p1 && !p2) || (p2 && !p1) ? 'BYE' : null
    });
  }

  // Generate placeholder matches for subsequent rounds
  // Total matches in a single elimination bracket = p - 1
  let currentRoundMatches = p / 2;
  let round = 2;
  while (currentRoundMatches > 1) {
    currentRoundMatches /= 2;
    for (let i = 0; i < currentRoundMatches; i++) {
      matches.push({
        tournament_id: tournamentId,
        round: round,
        match_index: ++matchIndex,
        player1_id: null,
        player2_id: null,
        status: 'PENDING'
      });
    }
    round++;
  }

  return matches;
}

module.exports = { generateSingleEliminationDraw };
