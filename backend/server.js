require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const { scrapeCalendar, getScrapeStatus } = require('./src/utils/aita_scraper');
const { scrapeRankings } = require('./src/utils/ranking_scraper');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors({ origin: '*' }));
app.use(express.json());

// Request logger
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: parseInt(process.env.DB_PORT || '5432'),
});

// Trigger ranking scraping
app.get('/api/scrape/rankings', async (req, res) => {
  try {
    scrapeRankings(); // Run in background
    res.json({ message: 'Ranking scraping started in background.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Autocomplete for player names
app.get('/api/players/autocomplete', async (req, res) => {
  const { query } = req.query;
  if (!query || query.length < 2) return res.json([]);
  try {
    const result = await pool.query(`
      SELECT full_name, aita_registration_number 
      FROM users 
      WHERE full_name ILIKE $1 OR aita_registration_number ILIKE $1
      LIMIT 10
    `, [`%${query}%`]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Player Dashboard
app.get('/api/players/:regNo/dashboard', async (req, res) => {
  const { regNo } = req.params;
  try {
    // 1. Basic Info
    const userRes = await pool.query('SELECT * FROM users WHERE aita_registration_number = $1', [regNo]);
    if (userRes.rows.length === 0) return res.status(404).json({ error: 'Player not found' });
    const user = userRes.rows[0];

    // 2. Current Rankings
    const ranksRes = await pool.query(`
      SELECT DISTINCT ON (category) category, rank, points, ranking_date
      FROM rankings
      WHERE player_id = $1
      ORDER BY category, ranking_date DESC
    `, [user.id]);
    const rankings = ranksRes.rows;

    // 3. Tournaments (Past & Upcoming)
    const tourRes = await pool.query(`
      SELECT t.*, tr.draw_type, tr.category_label, tr.player_rank
      FROM tournaments t
      JOIN tournament_registrations tr ON t.id = tr.tournament_id
      WHERE tr.player_id = $1
      ORDER BY t.start_date DESC
    `, [user.id]);
    
    const now = new Date();
    const pastTournaments = tourRes.rows.filter(t => new Date(t.start_date) < now);
    const upcomingTournaments = tourRes.rows.filter(t => new Date(t.start_date) >= now);

    // Calculate age and eligibility
    const birthYear = user.date_of_birth ? new Date(user.date_of_birth).getFullYear() : null;
    const currentYear = new Date().getFullYear();
    const ageAtEndOfYear = birthYear ? (currentYear - birthYear) : null;

    // 4. Calculate Eligible Categories for SQL matching
    const eligibleCategories = [];
    if (ageAtEndOfYear !== null) {
      if (ageAtEndOfYear <= 12) eligibleCategories.push('Under 12');
      if (ageAtEndOfYear <= 14) eligibleCategories.push('Under 14');
      if (ageAtEndOfYear <= 16) eligibleCategories.push('Under 16');
      if (ageAtEndOfYear <= 18) eligibleCategories.push('Under 18');
      if (ageAtEndOfYear >= 13) eligibleCategories.push('Men', 'Women');
    }
    console.log(`Player ${regNo} age: ${ageAtEndOfYear}, eligibleCats:`, eligibleCategories);

    // 5. Fetch ALL upcoming tournaments in those categories
    let eligibleUpcomingTournaments = [];
    if (eligibleCategories.length > 0) {
      const eligibleRes = await pool.query(`
        SELECT * FROM tournaments 
        WHERE start_date >= $1 
        AND category = ANY($2)
        ORDER BY start_date ASC
      `, [now, eligibleCategories]);
      
      console.log(`Found ${eligibleRes.rows.length} eligible upcoming tournaments`);
      
      eligibleUpcomingTournaments = eligibleRes.rows.map(t => {
        // Check if player is already registered (in an acceptance list)
        const reg = upcomingTournaments.find(ut => ut.id === t.id);
        return {
          ...t,
          isRegistered: !!reg,
          drawType: reg ? reg.draw_type : null,
          playerRank: reg ? reg.player_rank : null
        };
      });
    }

    res.json({
      player: {
        ...user,
        age: ageAtEndOfYear
      },
      rankings,
      pastTournaments,
      upcomingTournaments,
      eligibleUpcomingTournaments
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/hello', (req, res) => {
  res.json({ message: 'Hello World from Node.js Backend!' });
});

// Trigger scraping
app.get('/api/scrape', async (req, res) => {
  try {
    const year = req.query.year || 2026;
    scrapeCalendar(year); // Run in background
    res.json({ message: `Scraping for ${year} started in background.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Check scraping status
app.get('/api/scrape/status', (req, res) => {
  res.json(getScrapeStatus());
});

// Get all AITA tournaments with optional search/filters
app.get('/api/tournaments', async (req, res) => {
  const { search, category } = req.query;
  try {
    let query = 'SELECT * FROM tournaments WHERE aita_id IS NOT NULL';
    const params = [];

    if (search) {
      const keywords = search.split(/\s+/).filter(k => k.length > 0);
      keywords.forEach((word, index) => {
        params.push(`%${word}%`);
        query += ` AND (title ILIKE $${params.length} OR location ILIKE $${params.length} OR category ILIKE $${params.length})`;
      });
    }

    if (category) {
      params.push(category);
      query += ` AND category = $${params.length}`;
    }

    query += ' ORDER BY start_date ASC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get acceptance list for a tournament
app.get('/api/tournaments/:id/players', async (req, res) => {
  try {
    const query = `
      SELECT u.full_name, u.aita_registration_number, tr.draw_type, tr.player_rank, tr.player_state, tr.category_label
      FROM users u
      JOIN tournament_registrations tr ON u.id = tr.player_id
      WHERE tr.tournament_id = $1
      ORDER BY 
        CASE 
          WHEN tr.draw_type = 'MAIN DRAW' THEN 1
          WHEN tr.draw_type = 'QUALIFYING' THEN 2
          WHEN tr.draw_type = 'ALTERNATE' THEN 3
          WHEN tr.draw_type = 'WITHDRAWAL' THEN 4
          ELSE 5
        END,
        NULLIF(tr.player_rank, '')::INTEGER ASC NULLS LAST,
        u.full_name ASC
    `;
    const result = await pool.query(query, [req.params.id]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Search for a player and find all their tournaments
app.get('/api/players/search', async (req, res) => {
  const { name } = req.query;
  try {
    const query = `
      SELECT u.full_name, u.aita_registration_number, u.state, t.title, t.start_date, t.location, t.category, tr.draw_type, tr.player_rank, tr.category_label
      FROM users u
      JOIN tournament_registrations tr ON u.id = tr.player_id
      JOIN tournaments t ON tr.tournament_id = t.id
      WHERE u.full_name ILIKE $1
      ORDER BY t.start_date ASC
    `;
    const result = await pool.query(query, [`%${name}%`]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/db-test', async (req, res) => {
  try {
    const result = await pool.query('SELECT name FROM roles');
    res.json({ roles: result.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
