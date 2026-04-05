require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const { scrapeCalendar, getScrapeStatus } = require('./src/utils/aita_scraper');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: parseInt(process.env.DB_PORT || '5432'),
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
      params.push(`%${search}%`);
      query += ` AND (title ILIKE $${params.length} OR location ILIKE $${params.length})`;
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
