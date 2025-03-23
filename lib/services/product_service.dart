import 'package:whoosh/models/product_model.dart';
import 'package:whoosh/services/api_service.dart';

class ProductService {
  final _apiService = ApiService();

  Future<List<Product>> getProducts() async {
    final response = await _apiService.getProducts();
    return response.data;
  }
}
