const { Client } = require('pg');
require('dotenv').config({ path: '../.env' });

const client = new Client({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

async function updateSchema() {
  try {
    await client.connect();
    console.log('Connected to PostgreSQL. Updating schema...');

    // 1. Update tournaments table
    await client.query(`
      ALTER TABLE tournaments 
      ADD COLUMN IF NOT EXISTS aita_id INTEGER,
      ADD COLUMN IF NOT EXISTS category TEXT,
      ADD COLUMN IF NOT EXISTS fact_sheet_url TEXT,
      ADD COLUMN IF NOT EXISTS acceptance_list_url TEXT;
    `);

    // Add unique constraint to aita_id if not exists
    await client.query(`
      DO $$ 
      BEGIN 
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'aita_id_unique') THEN
          ALTER TABLE tournaments ADD CONSTRAINT aita_id_unique UNIQUE (aita_id);
        END IF;
      END $$;
    `);

    // 2. Make owner_id nullable for scraped tournaments
    await client.query(`
      ALTER TABLE tournaments 
      ALTER COLUMN owner_id DROP NOT NULL;
    `);

    // 3. Update users table for AITA registration
    await client.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS aita_registration_number TEXT UNIQUE,
      ADD COLUMN IF NOT EXISTS state TEXT;
    `);

    // 4. Update tournament_registrations with detailed columns
    await client.query(`
      ALTER TABLE tournament_registrations 
      ADD COLUMN IF NOT EXISTS draw_type TEXT, -- MAIN DRAW, QUALIFYING, ALTERNATE, WITHDRAWAL
      ADD COLUMN IF NOT EXISTS category_label TEXT, -- e.g. Boys Under 12
      ADD COLUMN IF NOT EXISTS player_rank TEXT,
      ADD COLUMN IF NOT EXISTS player_state TEXT;
    `);

    // 5. Update tournaments table: more accurate location
    await client.query(`
      ALTER TABLE tournaments 
      ADD COLUMN IF NOT EXISTS week_text TEXT;
    `);

    console.log('Schema updated successfully.');
  } catch (err) {
    console.error('Error updating schema:', err);
  } finally {
    await client.end();
  }
}

updateSchema();
