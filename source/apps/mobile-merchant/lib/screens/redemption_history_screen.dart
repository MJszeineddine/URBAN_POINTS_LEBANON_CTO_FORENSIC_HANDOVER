// Redemption History Screen
class RedemptionHistoryScreen extends StatefulWidget {
  const RedemptionHistoryScreen({Key? key}) : super(key: key);
  
  @override
  State<RedemptionHistoryScreen> createState() => _RedemptionHistoryScreenState();
}

class _RedemptionHistoryScreenState extends State<RedemptionHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Redemption History')),
      body: const Center(child: Text('History')),
    );
  }
}
