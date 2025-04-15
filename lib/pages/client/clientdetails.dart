import 'package:flutter/material.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:woosh/utils/app_theme.dart';

class ClientDetailsPage extends StatefulWidget {
  final Outlet outlet;

  const ClientDetailsPage({super.key, required this.outlet});

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  String? _locationDescription;

  @override
  void initState() {
    super.initState();
    _decodeLocation();
  }

  Future<void> _decodeLocation() async {
    if (widget.outlet.latitude != null && widget.outlet.longitude != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          widget.outlet.latitude!,
          widget.outlet.longitude!,
        );
        final placemark = placemarks.first;
        setState(() {
          _locationDescription =
              "${placemark.street}, ${placemark.locality}, ${placemark.country}";
        });
      } catch (e) {
        _locationDescription = "Location unavailable";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final outlet = widget.outlet;

    return Scaffold(
      appBar: AppBar(
        title: Text(outlet.name),
        backgroundColor: goldMiddle2,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: appBackground,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CreamGradientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GradientText(
                        'Client Details',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _ticketRow("Client", outlet.name),
                    _ticketRow("Address", outlet.address),
                    if (outlet.balance != null && outlet.balance!.isNotEmpty)
                      _ticketRow("Balance", "Ksh ${outlet.balance!}",
                          highlight: true),
                    if (outlet.email != null && outlet.email!.isNotEmpty)
                      _ticketRow("Email", outlet.email!),
                    if (outlet.phone != null && outlet.phone!.isNotEmpty)
                      _ticketRow("Phone", outlet.phone!),
                    if (outlet.kraPin != null && outlet.kraPin!.isNotEmpty)
                      _ticketRow("KRA PIN", outlet.kraPin!),
                    const SizedBox(height: 14),
                    _dashedDivider(),
                    const SizedBox(height: 14),
                    _ticketRow(
                      "Coordinates",
                      outlet.latitude != null
                          ? "${outlet.latitude!.toStringAsFixed(5)}, ${outlet.longitude!.toStringAsFixed(5)}"
                          : "Not available",
                      icon: Icons.location_on_outlined,
                    ),
                    if (_locationDescription != null)
                      _ticketRow("Location", _locationDescription!,
                          icon: Icons.place),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: GradientDecoration.goldCircular(),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
    );
  }

  Widget _ticketRow(String label, String value,
      {bool highlight = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(icon, size: 18, color: goldMiddle2),
            ),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: "$label: ",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: blackColor,
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          highlight ? FontWeight.bold : FontWeight.normal,
                      color: highlight ? goldStart : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashedDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        20,
        (_) => Container(
          width: 4,
          height: 1.5,
          color: goldMiddle2.withOpacity(0.6),
        ),
      ),
    );
  }
}
