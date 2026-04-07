const { Client } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

console.log('DB_NAME from env:', process.env.DB_NAME ? 'PRESENT' : 'MISSING');

const client = new Client({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

async function updateSchemaV2() {
  try {
    await client.connect();
    console.log('Connected to PostgreSQL. Updating schema (v2)...');

    // 1. Add date_of_birth to users
    await client.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS date_of_birth DATE;
    `);

    // 2. Add withdrawal_deadline and sign_in_date to tournaments
    await client.query(`
      ALTER TABLE tournaments 
      ADD COLUMN IF NOT EXISTS withdrawal_deadline DATE,
      ADD COLUMN IF NOT EXISTS sign_in_date TEXT;
    `);

    // 3. Create rankings table
    await client.query(`
      CREATE TABLE IF NOT EXISTS rankings (
        id SERIAL PRIMARY KEY,
        player_id INTEGER NOT NULL REFERENCES users(id),
        category TEXT NOT NULL,
        rank INTEGER NOT NULL,
        points FLOAT,
        ranking_date DATE NOT NULL,
        UNIQUE (player_id, category, ranking_date)
      );
    `);

    console.log('Schema updated (v2) successfully.');
  } catch (err) {
    console.error('Error updating schema (v2):', err);
  } finally {
    await client.end();
  }
}

updateSchemaV2();
