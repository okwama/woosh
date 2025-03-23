import 'package:whoosh/models/product_model.dart';
import 'package:whoosh/services/api_service.dart';

class ProductService {
  Future<List<Product>> getProducts() async {
    return await ApiService.getProducts();
  }
}
