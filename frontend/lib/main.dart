import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AITA Tournament Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const AITAHome(),
    );
  }
}

class AITAHome extends StatefulWidget {
  const AITAHome({super.key});

  @override
  State<AITAHome> createState() => _AITAHomeState();
}

class _AITAHomeState extends State<AITAHome> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _baseUrl = 'https://mae-interregnal-carmen.ngrok-free.dev';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AITA Tournament Tracker'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events), text: 'Tournaments'),
            Tab(icon: Icon(Icons.person_search), text: 'Player Search'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TournamentList(baseUrl: _baseUrl),
          PlayerSearch(baseUrl: _baseUrl),
        ],
      ),
    );
  }
}

class TournamentList extends StatefulWidget {
  final String baseUrl;
  const TournamentList({super.key, required this.baseUrl});

  @override
  State<TournamentList> createState() => _TournamentListState();
}

class _TournamentListState extends State<TournamentList> {
  List<dynamic> _tournaments = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  Future<void> _fetchTournaments({String? search}) async {
    setState(() => _isLoading = true);
    try {
      String url = '${widget.baseUrl}/api/tournaments';
      if (search != null && search.isNotEmpty) {
        url += '?search=${Uri.encodeComponent(search)}';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() => _tournaments = json.decode(response.body));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching tournaments: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search City or Tournament',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _fetchTournaments(search: _searchController.text),
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (val) => _fetchTournaments(search: val),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _fetchTournaments(search: _searchController.text),
                  child: ListView.builder(
                    itemCount: _tournaments.length,
                    itemBuilder: (context, index) {
                      final t = _tournaments[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: ListTile(
                          title: Text(t['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(t['location'] ?? 'N/A')),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.category, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(t['category'] ?? 'N/A'),
                                ],
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t['start_date'] != null 
                                  ? DateFormat('MMM dd').format(DateTime.parse(t['start_date']))
                                  : 'N/A',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => TournamentDetail(tournament: t, baseUrl: widget.baseUrl)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class TournamentDetail extends StatelessWidget {
  final dynamic tournament;
  final String baseUrl;
  const TournamentDetail({super.key, required this.tournament, required this.baseUrl});

  Future<Map<String, List<dynamic>>> _fetchAndGroupPlayers() async {
    final response = await http.get(Uri.parse('$baseUrl/api/tournaments/${tournament['id']}/players'));
    if (response.statusCode == 200) {
      List<dynamic> players = json.decode(response.body);
      Map<String, List<dynamic>> grouped = {};
      for (var p in players) {
        String section = p['draw_type'] ?? 'UNKNOWN';
        grouped.putIfAbsent(section, () => []).add(p);
      }
      return grouped;
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tournament['title'])),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blueAccent.withOpacity(0.05),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DetailRow(icon: Icons.location_on, text: tournament['location'] ?? 'N/A'),
                DetailRow(icon: Icons.category, text: tournament['category'] ?? 'N/A'),
                DetailRow(icon: Icons.calendar_today, text: DateFormat('MMMM dd, yyyy').format(DateTime.parse(tournament['start_date']))),
                if (tournament['withdrawal_deadline'] != null)
                  DetailRow(
                    icon: Icons.warning_amber_rounded, 
                    text: 'Withdrawal Deadline: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(tournament['withdrawal_deadline']))}',
                    color: Colors.redAccent,
                  ),
                if (tournament['sign_in_date'] != null)
                  DetailRow(icon: Icons.access_time, text: 'Sign-in: ${tournament['sign_in_date']}'),
                if (tournament['fact_sheet_url'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: () {}, 
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('View Fact Sheet'),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, List<dynamic>>>(
              future: _fetchAndGroupPlayers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Acceptance list not available yet.'));
                }
                
                var sections = snapshot.data!;
                return ListView(
                  children: sections.keys.map((section) {
                    return ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(section, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      children: sections[section]!.map((p) {
                        return ListTile(
                          title: Text(p['full_name']),
                          subtitle: Text('${p['player_state']} | Rank: ${p['player_rank'] ?? "N/A"}'),
                          trailing: Text(p['aita_registration_number'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        );
                      }).toList(),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const DetailRow({super.key, required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 15, color: color, fontWeight: color != null ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }
}

class PlayerSearch extends StatefulWidget {
  final String baseUrl;
  const PlayerSearch({super.key, required this.baseUrl});

  @override
  State<PlayerSearch> createState() => _PlayerSearchState();
}

class _PlayerSearchState extends State<PlayerSearch> {
  final TextEditingController _controller = TextEditingController();

  Future<List<dynamic>> _getSuggestions(String query) async {
    if (query.length < 2) return [];
    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/api/players/autocomplete?query=${Uri.encodeComponent(query)}'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Autocomplete error: $e');
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'Search for a Player Dashboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Autocomplete<Map<String, dynamic>>(
            displayStringForOption: (option) => '${option['full_name']} (${option['aita_registration_number']})',
            optionsBuilder: (TextEditingValue value) => _getSuggestions(value.text).then((list) => list.cast<Map<String, dynamic>>()),
            onSelected: (option) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerDashboard(
                    regNo: option['aita_registration_number'],
                    baseUrl: widget.baseUrl,
                  ),
                ),
              );
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Enter Name or AITA Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_search),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          const Icon(Icons.dashboard_customize, size: 100, color: Colors.blueAccent),
          const SizedBox(height: 16),
          const Text(
            'Select a player to see their full profile, rankings, and tournament history.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class PlayerDashboard extends StatefulWidget {
  final String regNo;
  final String baseUrl;
  const PlayerDashboard({super.key, required this.regNo, required this.baseUrl});

  @override
  State<PlayerDashboard> createState() => _PlayerDashboardState();
}

class _PlayerDashboardState extends State<PlayerDashboard> {
  late Future<Map<String, dynamic>> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = _fetchDashboard();
  }

  Future<Map<String, dynamic>> _fetchDashboard() async {
    final response = await http.get(Uri.parse('${widget.baseUrl}/api/players/${widget.regNo}/dashboard'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load dashboard');
  }

  List<String> _getEligibleCategories(int? age) {
    if (age == null) return ['N/A'];
    List<String> cats = [];
    if (age <= 12) cats.add('Under 12');
    if (age <= 14) cats.add('Under 14');
    if (age <= 16) cats.add('Under 16');
    if (age <= 18) cats.add('Under 18');
    if (age >= 13) cats.add('Men/Women');
    return cats.isEmpty ? ['Open'] : cats;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Player Dashboard')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final player = data['player'];
          final rankings = data['rankings'] as List;
          final past = data['pastTournaments'] as List;
          final eligibleUpcoming = data['eligibleUpcomingTournaments'] as List? ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blueAccent,
                        child: Text(player['full_name'][0], style: const TextStyle(fontSize: 24, color: Colors.white)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(player['full_name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('AITA: ${player['aita_registration_number']}'),
                            Text('DOB: ${player['date_of_birth'] ?? "N/A"} | Age: ${player['age'] ?? "N/A"}'),
                            Text('State: ${player['state'] ?? "N/A"}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const SectionHeader(title: 'Eligible Categories', icon: Icons.check_circle_outline),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8,
                    children: _getEligibleCategories(player['age']).map((cat) => Chip(
                      label: Text(cat),
                      backgroundColor: Colors.green.withOpacity(0.1),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const SectionHeader(title: 'Current Rankings', icon: Icons.leaderboard),
              if (rankings.isEmpty)
                const Card(child: ListTile(title: Text('No rankings found.')))
              else
                ...rankings.map((r) => Card(
                      child: ListTile(
                        title: Text(r['category']),
                        trailing: Text('#${r['rank']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        subtitle: Text('Points: ${r['points']} | As of: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(r['ranking_date']))}'),
                      ),
                    )),
              const SizedBox(height: 16),

              const SectionHeader(title: 'Upcoming Eligible Tournaments', icon: Icons.event),
              if (eligibleUpcoming.isEmpty)
                const Card(child: ListTile(title: Text('No upcoming tournaments found for your category.')))
              else
                ...eligibleUpcoming.map((t) => TournamentCard(tournament: t, isUpcoming: true)),

              const SizedBox(height: 16),

              const SectionHeader(title: 'Past Appearances', icon: Icons.history),
              if (past.isEmpty)
                const Card(child: ListTile(title: Text('No past tournaments found.')))
              else
                ...past.map((t) => TournamentCard(tournament: t, isUpcoming: false)),
            ],
          );
        },
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const SectionHeader({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class TournamentCard extends StatelessWidget {
  final dynamic tournament;
  final bool isUpcoming;
  const TournamentCard({super.key, required this.tournament, required this.isUpcoming});

  @override
  Widget build(BuildContext context) {
    final isRegistered = tournament['isRegistered'] == true;

    return Card(
      elevation: isRegistered ? 4 : 1,
      shape: isRegistered ? RoundedRectangleBorder(side: const BorderSide(color: Colors.green, width: 2), borderRadius: BorderRadius.circular(12)) : null,
      child: ListTile(
        title: Text(tournament['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${tournament['category_label'] ?? tournament['category']}'),
            Text('Start: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(tournament['start_date']))}'),
            if (isUpcoming) ...[
              if (isRegistered && tournament['withdrawal_deadline'] != null)
                Text(
                  'Withdrawal Deadline: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(tournament['withdrawal_deadline']))}',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              if (!isRegistered && tournament['sign_in_date'] != null)
                Text(
                  'Sign-in: ${tournament['sign_in_date']}',
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isRegistered)
              const Badge(
                label: Text('REGISTERED'),
                backgroundColor: Colors.green,
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.blueAccent.withOpacity(0.1),
              child: Text(
                isRegistered ? (tournament['drawType'] ?? 'MD') : 'INFO', 
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
              ),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TournamentDetail(tournament: tournament, baseUrl: 'https://mae-interregnal-carmen.ngrok-free.dev')),
        ),
      ),
    );
  }
}
