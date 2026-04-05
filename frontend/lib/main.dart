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
  const DetailRow({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
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
  List<dynamic> _results = [];
  bool _isLoading = false;
  final TextEditingController _nameController = TextEditingController();

  Future<void> _searchPlayer(String name) async {
    if (name.length < 3) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/api/players/search?name=${Uri.encodeComponent(name)}'));
      if (response.statusCode == 200) {
        setState(() => _results = json.decode(response.body));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Enter Player Name',
              hintText: 'Search by full name...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            onChanged: (val) => _searchPlayer(val),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? const Center(child: Text('No players found. Try typing a name.'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final r = _results[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(child: Text(r['full_name'][0])),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(r['full_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                          Text('AITA: ${r['aita_registration_number']} | State: ${r['state'] ?? "N/A"}'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(r['title'], style: const TextStyle(fontWeight: FontWeight.bold))),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      color: Colors.blueAccent.withOpacity(0.1),
                                      child: Text(r['draw_type'] ?? 'PENDING', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Category: ${r['category_label'] ?? r['category']}'),
                                Text('Location: ${r['location']}'),
                                Text('Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(r['start_date']))}'),
                                if (r['player_rank'] != null && r['player_rank'].toString().isNotEmpty)
                                  Text('Rank in List: ${r['player_rank']}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
