import 'package:woosh/models/product_model.dart';
import 'package:woosh/services/api_service.dart';

class ProductService {
  Future<List<Product>> getProducts() async {
    return await ApiService.getProducts();
  }
}
