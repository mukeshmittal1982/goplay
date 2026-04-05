const { Client } = require('pg');
require('dotenv').config({ path: '../.env' }); // Adjusted path to .env

const client = new Client({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

async function initDB() {
  try {
    await client.connect();
    console.log('Connected to PostgreSQL. Initializing database...');

    await client.query(`CREATE TABLE IF NOT EXISTS roles (id SERIAL PRIMARY KEY, name TEXT NOT NULL UNIQUE)`);
    
    await client.query(`CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      full_name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      role_id INTEGER NOT NULL REFERENCES roles(id)
    )`);

    await client.query(`CREATE TABLE IF NOT EXISTS tournaments (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL,
      start_date TIMESTAMP,
      location TEXT,
      owner_id INTEGER NOT NULL REFERENCES users(id),
      status TEXT DEFAULT 'DRAFT'
    )`);

    await client.query(`CREATE TABLE IF NOT EXISTS tournament_registrations (
      tournament_id INTEGER NOT NULL REFERENCES tournaments(id),
      player_id INTEGER NOT NULL REFERENCES users(id),
      PRIMARY KEY (tournament_id, player_id)
    )`);

    await client.query(`CREATE TABLE IF NOT EXISTS matches (
      id SERIAL PRIMARY KEY,
      tournament_id INTEGER NOT NULL REFERENCES tournaments(id),
      round INTEGER NOT NULL,
      match_index INTEGER NOT NULL,
      player1_id INTEGER REFERENCES users(id),
      player2_id INTEGER REFERENCES users(id),
      winner_id INTEGER REFERENCES users(id),
      score_text TEXT,
      status TEXT DEFAULT 'PENDING'
    )`);

    // Seed initial roles
    const roles = ['Owner', 'Player', 'Parent'];
    for (const role of roles) {
      await client.query(`INSERT INTO roles (name) VALUES ($1) ON CONFLICT (name) DO NOTHING`, [role]);
    }

    console.log('Database initialized successfully.');
  } catch (err) {
    console.error('Error initializing database:', err);
  } finally {
    await client.end();
  }
}

initDB();
