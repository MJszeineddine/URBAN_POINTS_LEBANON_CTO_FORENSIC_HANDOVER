// Offer Creation Screen
class OfferCreationScreen extends StatefulWidget {
  const OfferCreationScreen({Key? key}) : super(key: key);
  
  @override
  State<OfferCreationScreen> createState() => _OfferCreationScreenState();
}

class _OfferCreationScreenState extends State<OfferCreationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Offer')),
      body: const Center(child: Text('Offer Creation')),
    );
  }
}
