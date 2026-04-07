const axios = require('axios');
const cheerio = require('cheerio');
const { PDFParse } = require('pdf-parse');
const { Pool } = require('pg');
const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: parseInt(process.env.DB_PORT || '5432'),
});

const RANKING_URL = 'https://aitatennis.com/playerranking/';

const CATEGORIES = [
  { name: 'Boys', subcats: ['Under 12', 'Under 14', 'Under 16', 'Under 18'] },
  { name: 'Girls', subcats: ['Under 12', 'Under 14', 'Under 16', 'Under 18'] },
  { name: 'Men', subcats: ['Men'] },
  { name: 'Women', subcats: ['Women'] }
];

async function scrapeRankings() {
  console.log('Starting AITA Ranking Scrape...');
  for (const cat of CATEGORIES) {
    for (const subcat of cat.subcats) {
      try {
        console.log(`Processing ${cat.name} - ${subcat}...`);
        const pdfUrl = await getLatestRankingPdfUrl(cat.name, subcat);
        if (pdfUrl) {
          console.log(`Found PDF: ${pdfUrl}`);
          const rankingDate = extractDateFromUrl(pdfUrl);
          await parseAndSaveRanking(pdfUrl, cat.name, subcat, rankingDate);
        } else {
          console.warn(`No PDF found for ${cat.name} - ${subcat}`);
        }
      } catch (err) {
        console.error(`Error processing ${cat.name} ${subcat}:`, err.message);
      }
    }
  }
}

async function getLatestRankingPdfUrl(category, subcategory) {
  try {
    const response = await axios.post(RANKING_URL, `category=${category}&sub_category=${subcategory}&submit=Ranking`, {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    });
    
    const $ = cheerio.load(response.data);
    const pdfLink = $('a[href$=".pdf"]').first().attr('href');
    return pdfLink;
  } catch (err) {
    console.error('Error fetching PDF URL:', err.message);
    return null;
  }
}

function extractDateFromUrl(url) {
  const match = url.match(/(\d{2})-(\d{2})-(\d{4})\.pdf$/);
  if (match) {
    return new Date(`${match[3]}-${match[2]}-${match[1]}`);
  }
  return new Date(); 
}

async function parseAndSaveRanking(pdfSource, category, subcategory, rankingDate, isLocal = false) {
  try {
    let dataBuffer;
    if (isLocal) {
      dataBuffer = fs.readFileSync(pdfSource);
    } else {
      const response = await axios.get(pdfSource, { responseType: 'arraybuffer' });
      dataBuffer = response.data;
    }

    const parser = new PDFParse({ data: dataBuffer });
    const result = await parser.getText();
    const text = result.text;
    
    const lines = text.split('\n');
    const categoryLabel = `${category} ${subcategory}`;
    let count = 0;
    
    for (const line of lines) {
      // Improved Regex for AITA Ranking PDF
      const match = line.match(/^(\d+)\s+(.+?)\s+(\d{6})\s+(\d{2}-[A-Za-z]{3}-\d{2})\s+\(([^)]+)\).*\s+([\d.]+)$/);
      
      if (match) {
        const [_, rank, fullName, regNo, dobStr, state, points] = match;
        const dob = parseAitaDob(dobStr);
        
        await savePlayerRanking({
          fullName: fullName.trim(),
          regNo: regNo.trim(),
          points: parseFloat(points),
          rank: parseInt(rank),
          dob,
          state,
          category: categoryLabel,
          rankingDate
        });
        count++;
      }
    }
    await parser.destroy();
    console.log(`Successfully parsed ${count} players for ${categoryLabel}`);
  } catch (err) {
    console.error('Error parsing PDF:', err.message);
  }
}

function parseAitaDob(dobStr) {
  // Format: 30-Nov-11 or 15-05-2012
  const parts = dobStr.split('-');
  if (parts.length === 3) {
    let day = parts[0];
    let monthStr = parts[1];
    let year = parts[2];

    const months = {
      'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04', 'May': '05', 'Jun': '06',
      'Jul': '07', 'Aug': '08', 'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
    };

    let month = months[monthStr] || monthStr;
    
    if (year.length === 2) {
      // Assume 20XX for now, adjust if needed for seniors
      year = '20' + year;
    }

    return new Date(`${year}-${month}-${day}`);
  }
  return null;
}

async function savePlayerRanking(data) {
  try {
    const roleIdResult = await pool.query("SELECT id FROM roles WHERE name = 'Player'");
    const roleId = roleIdResult.rows[0].id;
    const email = `aita_${data.regNo}@example.com`;

    const userRes = await pool.query(`
      INSERT INTO users (full_name, email, role_id, aita_registration_number, date_of_birth, state)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (aita_registration_number) DO UPDATE SET 
        full_name = EXCLUDED.full_name,
        date_of_birth = EXCLUDED.date_of_birth,
        state = EXCLUDED.state
      RETURNING id
    `, [data.fullName, email, roleId, data.regNo, data.dob, data.state]);

    const playerId = userRes.rows[0].id;

    await pool.query(`
      INSERT INTO rankings (player_id, category, rank, points, ranking_date)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (player_id, category, ranking_date) DO UPDATE SET
        rank = EXCLUDED.rank,
        points = EXCLUDED.points
    `, [playerId, data.category, data.rank, data.points, data.rankingDate]);

  } catch (err) {
    // console.error(`Error saving ranking for ${data.fullName}:`, err.message);
  }
}

module.exports = { scrapeRankings, parseAndSaveRanking };
