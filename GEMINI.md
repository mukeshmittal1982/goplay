# AITA Tournament Tracker (Goplay)

## Project Overview
An application to track AITA (All India Tennis Association) tournaments, acceptance lists, and player rankings. It allows players and parents to search for tournaments by city/category and see where specific players are registered.

## Tech Stack
- **Frontend:** Flutter (Mobile & Web)
- **Backend:** Node.js + Express
- **Database:** PostgreSQL
- **Tools:** `axios` + `cheerio` (Scraping), `ngrok` (Mobile testing)

## Project Structure
- `backend/`: Node.js server and database logic.
  - `server.js`: API endpoints and server entry point.
  - `src/utils/aita_scraper.js`: Scraper for AITA calendar and acceptance lists.
  - `database/`: Schema initialization and updates.
- `frontend/`: Flutter project.
  - `lib/main.dart`: Main UI with Tournament and Player search tabs.

## Current State
- **Connectivity:** Backend is exposed via ngrok for physical device testing.
- **Scraper:** Can scrape the AITA 2026 calendar and drill down into acceptance lists (Main Draw, Qualifying, etc.).
- **Database:** PostgreSQL stores tournaments, players, and registrations with unique constraints.
- **UI:** Modern Material 3 interface with search, filters, and grouped acceptance lists.

## Future Plans
- Integrate AITA Player Ranking PDFs.
- Add "My Watchlist" for tracking specific players.
- Implement notifications for acceptance list updates.
