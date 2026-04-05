=== TENNIS APP (GOPLAY) - QUICK START GUIDE ===

--- 1. STARTING THE SYSTEM ---

[Backend]
cd backend && npm run start
(Runs on http://localhost:3000)

[Frontend]
cd frontend && flutter run -d chrome  # For Web
cd frontend && flutter run           # For Phone (USB connected)

--- 2. STOPPING & RESTARTING ---

To Kill everything (Fresh Start):
pkill -9 -f node && pkill -9 -f flutter

To check if any node processes are still hanging:
ps aux | grep node

--- 3. SCRAPER COMMANDS ---

[Start Scraper]
Visit: http://localhost:3000/api/scrape?year=2026

[Check Status]
Visit: http://localhost:3000/api/scrape/status

--- 4. VERIFYING DEPENDENCIES ---

[PostgreSQL]
Run: psql -h localhost -U postgres -d postgres
(Type \dt to see tables)

[ngrok]
Run: curl -s http://localhost:4040/api/tunnels
Public URL: https://mae-interregnal-carmen.ngrok-free.dev

--- 5. USEFUL LINKS ---
- AITA Calendar: https://aitatennis.com/management/calendar.php?year=2026
- Local Backend: http://localhost:3000/hello
- Tournament API: http://localhost:3000/api/tournaments
- Scraper Progress: http://localhost:3000/api/scrape/status
