import 'package:flutter/material.dart';
import 'package:glamour_queen/models/client_model.dart';

class ClientListItem extends StatelessWidget {
  final Client client;
  final VoidCallback? onTap;

  const ClientListItem({
    super.key,
    required this.client,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final balance = double.tryParse(client.balance ?? '0') ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(
          client.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (client.address.isNotEmpty ?? false)
              Text(
                client.address ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (client.contact?.isNotEmpty ?? false)
              Text(
                'Contact: ${client.contact}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Balance: ${client.balance}',
              style: TextStyle(
                color: balance > 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (client.clientType != null)
              Text(
                'Type: ${client.clientType}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

