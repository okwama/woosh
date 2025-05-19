import 'package:hive/hive.dart';
import '../../models/hive/client_model.dart';

class ClientHiveService {
  static const String _boxName = 'clients';
  late Box<ClientModel> _clientBox;

  Future<void> init() async {
    _clientBox = await Hive.openBox<ClientModel>(_boxName);
  }

  Future<void> saveClient(ClientModel client) async {
    await _clientBox.put(client.id, client);
  }

  Future<void> saveClients(List<ClientModel> clients) async {
    final Map<int, ClientModel> clientMap = {
      for (var client in clients) client.id: client
    };
    await _clientBox.putAll(clientMap);
  }

  ClientModel? getClient(int id) {
    return _clientBox.get(id);
  }

  List<ClientModel> getAllClients() {
    return _clientBox.values.toList();
  }

  List<ClientModel> searchClients(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _clientBox.values
        .where((client) =>
            client.name.toLowerCase().contains(lowercaseQuery) ||
            client.phone.contains(lowercaseQuery))
        .toList();
  }

  Future<void> deleteClient(int id) async {
    await _clientBox.delete(id);
  }

  Future<void> clearAllClients() async {
    await _clientBox.clear();
  }
}
