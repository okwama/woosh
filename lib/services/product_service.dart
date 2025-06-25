import 'package:glamour_queen/models/product_model.dart';
import 'package:glamour_queen/services/api_service.dart';

class ProductService {
  Future<List<Product>> getProducts() async {
    return await ApiService.getProducts();
  }
}

