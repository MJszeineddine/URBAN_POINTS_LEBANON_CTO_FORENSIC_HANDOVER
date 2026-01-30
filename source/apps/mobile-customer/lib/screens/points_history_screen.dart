import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../widgets/empty_states/history_empty_state.dart';

class PointsHistoryScreen extends StatefulWidget {
  const PointsHistoryScreen({super.key});

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  // ignore: unused_field
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  int _totalPointsEarned = 0;
  int _totalPointsRedeemed = 0;
  int _currentBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadPointsHistory();
  }

  Future<void> _loadPointsHistory() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get balance
      final balanceResult = await _functions.httpsCallable('getBalance').call();
      final balanceData = balanceResult.data as Map<String, dynamic>;
      _currentBalance = ((balanceData['balance'] as num?)?.toDouble() ?? 0).toInt();

      // Get history
      final historyResult = await _functions.httpsCallable('getPointsHistory').call();
      final historyData = historyResult.data as Map<String, dynamic>;
      final historyList = (historyData['history'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      _transactions = historyList.map((item) {
        return {
          'date': DateTime.parse(item['timestamp'] as String),
          'points': (item['points'] as num).toInt(),
          'description': item['description'] as String? ?? 'Transaction',
          'type': (item['points'] as num) > 0 ? 'earned' : 'redeemed',
        };
      }).toList();

      _totalPointsEarned = _transactions
          .where((t) => (t['points'] as int) > 0)
          .fold(0, (total, t) => total + (t['points'] as int));
      _totalPointsRedeemed = _transactions
          .where((t) => (t['points'] as int) < 0)
          .fold(0, (total, t) => total + (t['points'] as int).abs());

      setState(() => _isLoading = false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading points history: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Points History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPointsHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPointsSummaryCard(),
                  const SizedBox(height: 24),
                  _buildPointsTrendChart(),
                  const SizedBox(height: 24),
                  _buildEarnedVsRedeemedChart(),
                  const SizedBox(height: 24),
                  Text(
                    'Transaction History',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildTransactionsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildPointsSummaryCard() {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF00A859), Color(0xFF00D68F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Balance',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat('#,###').format(_currentBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'points',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Earned',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${NumberFormat('#,###').format(_totalPointsEarned)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Redeemed',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '-${NumberFormat('#,###').format(_totalPointsRedeemed)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsTrendChart() {
    // Generate cumulative points data
    List<FlSpot> spots = [];
    int cumulative = 0;
    
    for (int i = _transactions.length - 1; i >= 0; i--) {
      cumulative += _transactions[i]['points'] as int;
      spots.add(FlSpot((_transactions.length - 1 - i).toDouble(), cumulative.toDouble()));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Points Balance Trend',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 50),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFF00A859),
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF00A859).withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarnedVsRedeemedChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Earned vs Redeemed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: _totalPointsEarned.toDouble(),
                      title: 'Earned\n${NumberFormat('#,###').format(_totalPointsEarned)}',
                      color: const Color(0xFF00A859),
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: _totalPointsRedeemed.toDouble(),
                      title: 'Redeemed\n${NumberFormat('#,###').format(_totalPointsRedeemed)}',
                      color: Colors.orange,
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
      return const HistoryEmptyState();
    }

    return Column(
      children: _transactions.map((transaction) {
        final isEarned = transaction['type'] == 'earned';
        final points = transaction['points'] as int;
        final date = transaction['date'] as DateTime;
        final description = transaction['description'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isEarned
                  ? const Color(0xFF00A859).withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              child: Icon(
                isEarned ? Icons.add : Icons.remove,
                color: isEarned ? const Color(0xFF00A859) : Colors.orange,
              ),
            ),
            title: Text(
              description,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              DateFormat('MMM dd, yyyy - hh:mm a').format(date),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              '${isEarned ? '+' : ''}${NumberFormat('#,###').format(points)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isEarned ? const Color(0xFF00A859) : Colors.orange,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
