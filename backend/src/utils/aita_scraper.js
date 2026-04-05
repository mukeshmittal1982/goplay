const axios = require('axios');
const cheerio = require('cheerio');
const { Pool } = require('pg');
require('dotenv').config({ path: '../../.env' });

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: parseInt(process.env.DB_PORT || '5432'),
});

const BASE_URL = 'https://aitatennis.com/management/';

let scrapeStatus = {
  total: 0,
  processed: 0,
  status: 'IDLE',
  lastRun: null
};

function getScrapeStatus() {
  return scrapeStatus;
}

async function scrapeCalendar(year = 2026) {
  try {
    scrapeStatus = { total: 0, processed: 0, status: 'RUNNING', lastRun: new Date() };
    console.log(`Scraping AITA Calendar for ${year}...`);
    const response = await axios.get(`${BASE_URL}calendar.php?year=${year}`);
    const $ = cheerio.load(response.data);
    const tournaments = [];

    const headers = [];
    $('table.caland-table thead th').each((i, el) => {
      headers.push($(el).text().trim());
    });

    $('table.caland-table tbody tr').each((i, row) => {
      const cells = $(row).find('td');
      const weekText = $(cells[0]).text().trim().replace(/\s+/g, ' ');

      $(cells).each((j, cell) => {
        if (j === 0 || j === 6) return; 

        const link = $(cell).find('a');
        if (link.length > 0) {
          const title = link.text().trim();
          const href = link.attr('href');
          const aitaId = href.split('id=')[1];
          const category = headers[j];

          if (title && !title.includes('ITF') && !title.includes('ATF') && !title.includes('Asian')) {
            tournaments.push({
              aitaId,
              title,
              category,
              weekText,
              detailsUrl: `https://aitatennis.com/tournament-content/?id=${aitaId}`
            });
          }
        }
      });
    });

    scrapeStatus.total = tournaments.length;
    console.log(`Found ${tournaments.length} AITA tournaments. Processing details...`);
    for (const t of tournaments) {
      await scrapeTournamentDetails(t);
      await saveTournament(t);
      
      for (const list of t.acceptanceLists) {
        await scrapeAcceptanceList(t.aitaId, list);
      }
      scrapeStatus.processed++;
    }

    scrapeStatus.status = 'COMPLETED';
    console.log('Scraping completed successfully.');
  } catch (err) {
    scrapeStatus.status = 'ERROR';
    console.error('Error in scrapeCalendar:', err);
  }
}

async function scrapeTournamentDetails(t) {
  try {
    const response = await axios.get(t.detailsUrl);
    const $ = cheerio.load(response.data);

    const wrapper = $('.wpb_wrapper');
    const h4s = wrapper.find('h4');
    
    if (h4s.length >= 3) {
      t.location = `${$(h4s[1]).text().trim()}, ${$(h4s[2]).text().trim()}`;
    } else {
      t.location = "N/A";
    }

    const factSheetLink = $('a:contains("Fact Sheet")').attr('href');
    if (factSheetLink) t.factSheetUrl = factSheetLink;

    const acceptanceLists = [];
    $('a:contains("Under"), a:contains("Men"), a:contains("Women")').each((i, el) => {
      const href = $(el).attr('href');
      if (href && href.includes('acceptancelist')) {
        acceptanceLists.push({
          label: $(el).text().trim(),
          url: href.startsWith('http') ? href : `https://aitatennis.com/${href}`
        });
      }
    });
    t.acceptanceLists = acceptanceLists;

    const [day, monthStr] = t.weekText.split(',');
    const months = { 'Jan': 0, 'Feb': 1, 'Mar': 2, 'Apr': 3, 'May': 4, 'Jun': 5, 'Jul': 6, 'Aug': 7, 'Sep': 8, 'Oct': 9, 'Nov': 10, 'Dec': 11 };
    t.startDate = new Date(2026, months[monthStr.trim()] || 0, parseInt(day));

  } catch (err) {
    console.error(`Error details for ${t.aitaId}:`, err.message);
  }
}

async function scrapeAcceptanceList(aitaTournamentId, list) {
  try {
    const response = await axios.get(list.url);
    const $ = cheerio.load(response.data);
    
    const tourResult = await pool.query('SELECT id FROM tournaments WHERE aita_id = $1', [aitaTournamentId]);
    if (tourResult.rows.length === 0) return;
    const tournamentId = tourResult.rows[0].id;

    let currentDrawType = 'MAIN DRAW';
    const rows = $('table tr').get();

    for (const row of rows) {
      const text = $(row).text().toUpperCase();
      
      if (text.includes('MAIN DRAW')) currentDrawType = 'MAIN DRAW';
      else if (text.includes('QUALIFYING')) currentDrawType = 'QUALIFYING';
      else if (text.includes('ALTERNATE')) currentDrawType = 'ALTERNATE';
      else if (text.includes('WITHDRAWAL')) currentDrawType = 'WITHDRAWAL';

      const cells = $(row).find('td');
      if (cells.length >= 5) {
        const firstName = $(cells[1]).text().trim();
        const lastName = $(cells[2]).text().trim();
        const state = $(cells[3]).text().trim();
        const regNo = $(cells[4]).text().trim();
        const rank = cells.length >= 6 ? $(cells[5]).text().trim() : '';
        const fullName = `${firstName} ${lastName}`;

        if (regNo && firstName && firstName.toUpperCase() !== 'NAME') {
          await savePlayerAndRegistration({
            tournamentId,
            fullName,
            regNo,
            state,
            rank,
            drawType: currentDrawType,
            categoryLabel: list.label
          });
        }
      }
    }
  } catch (err) {
    console.error(`Error list ${list.url}:`, err.message);
  }
}

async function savePlayerAndRegistration(data) {
  try {
    const email = `aita_${data.regNo}@example.com`;
    const roleId = (await pool.query("SELECT id FROM roles WHERE name = 'Player'")).rows[0].id;

    const userRes = await pool.query(`
      INSERT INTO users (full_name, email, role_id, aita_registration_number, state)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (aita_registration_number) DO UPDATE SET full_name = EXCLUDED.full_name
      RETURNING id
    `, [data.fullName, email, roleId, data.regNo, data.state]);

    const playerId = userRes.rows[0].id;

    await pool.query(`
      INSERT INTO tournament_registrations (tournament_id, player_id, draw_type, category_label, player_rank, player_state)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (tournament_id, player_id) DO UPDATE SET
        draw_type = EXCLUDED.draw_type,
        category_label = EXCLUDED.category_label,
        player_rank = EXCLUDED.player_rank,
        player_state = EXCLUDED.player_state
    `, [data.tournamentId, playerId, data.drawType, data.categoryLabel, data.rank, data.state]);

  } catch (err) {
    if (err.code !== '23505') console.error(`Error savePlayer ${data.fullName}:`, err.message);
  }
}

async function saveTournament(t) {
  try {
    await pool.query(`
      INSERT INTO tournaments (aita_id, title, category, start_date, location, fact_sheet_url, status, week_text)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      ON CONFLICT (aita_id) DO UPDATE SET
        title = EXCLUDED.title,
        category = EXCLUDED.category,
        start_date = EXCLUDED.start_date,
        location = EXCLUDED.location,
        fact_sheet_url = EXCLUDED.fact_sheet_url,
        week_text = EXCLUDED.week_text
    `, [t.aitaId, t.title, t.category, t.startDate, t.location, t.factSheetUrl, 'ACTIVE', t.weekText]);
  } catch (err) {
    console.error(`Error saveTournament ${t.aitaId}:`, err.message);
  }
}

if (require.main === module) {
  scrapeCalendar();
}

module.exports = { scrapeCalendar, getScrapeStatus };
