import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/http_exception.dart';
import 'package:http/http.dart' as http;

import 'product.dart';

class Products with ChangeNotifier {
  List<Product> _items = [];

  // var _showFavoritesOnly = false;
  final String authToken;
  final String userId;

  Products(this.authToken, this.userId, this._items);

  List<Product> get items {
    // if(_showFavoritesOnly) {
    //   return _items.where((prodItem) => prodItem.isFavorite).toList();
    // }
    return [..._items];
  }

  List<Product> get favoriteItems {
    return _items.where((prodItem) => prodItem.isFavorite).toList();
  }

  Product findById(String id) {
    return _items.firstWhere((prod) => prod.id == id);
  }

  // void showFavoritesOnly () {
  //   _showFavoritesOnly = true;
  //   notifyListeners();
  // }

  // void showAll () {
  //   _showFavoritesOnly = false;
  //   notifyListeners();
  // }

  Future<void> fetchAndSetProducts([bool filterByUser = false]) async {
    final filterString =
        filterByUser ? 'orderBy="creatorId"&equalTo="$userId"' : '';
    var url =
        'https://flutter-update-71536-default-rtdb.firebaseio.com/products.json?auth=$authToken';
    if (filterString.isNotEmpty) {
      url += '&$filterString';
    }

    try {
      final response = await http.get(Uri.parse(url));
      print('Products response: ${response.body}'); // Debug print

      // Handle different response types
      final responseBody = response.body;
      if (responseBody == 'null' || responseBody.isEmpty) {
        _items = [];
        notifyListeners();
        return;
      }

      final extractedData = json.decode(responseBody);

      // Check if the response is a Map (expected format)
      if (extractedData is! Map<String, dynamic>) {
        print('Unexpected data format: ${extractedData.runtimeType}');
        _items = [];
        notifyListeners();
        return;
      }

      // Fetch favorites
      final favUrl =
          'https://flutter-update-71536-default-rtdb.firebaseio.com/userFavorites/$userId.json?auth=$authToken';
      final favoriteResponse = await http.get(Uri.parse(favUrl));

      Map<String, dynamic>? favoriteData;
      if (favoriteResponse.body != 'null' && favoriteResponse.body.isNotEmpty) {
        try {
          final favData = json.decode(favoriteResponse.body);
          if (favData is Map<String, dynamic>) {
            favoriteData = favData;
          }
        } catch (e) {
          print('Error parsing favorites: $e');
          favoriteData = null;
        }
      }

      final List<Product> loadedProducts = [];

      // Process each product with your correct Firebase structure
      extractedData.forEach((prodId, prodData) {
        try {
          if (prodData is Map<String, dynamic>) {
            loadedProducts.add(Product(
              id: prodId,
              title: prodData['title']?.toString() ?? 'Unknown Product',
              description:
                  prodData['description']?.toString() ?? 'No description',
              price: _parsePrice(prodData['price']),
              isFavorite: favoriteData?[prodId] == true,
              imageUrl: prodData['imageUrl']?.toString() ?? '',
            ));
          }
        } catch (e) {
          print('Error processing product $prodId: $e');
        }
      });

      _items = loadedProducts;
      notifyListeners();
    } catch (error) {
      print('Error fetching products: $error');
      _items = [];
      notifyListeners();
      throw error;
    }
  }

  // Helper method to safely parse price
  double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) {
      return double.tryParse(price) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> addProduct(Product product) async {
    final url =
        'https://flutter-update-71536-default-rtdb.firebaseio.com/products.json?auth=$authToken';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(
          {
            'title': product.title,
            'description': product.description,
            'imageUrl': product.imageUrl,
            'price': product.price,
            'creatorId': userId,
          },
        ),
      );
      final newProduct = Product(
        title: product.title,
        description: product.description,
        price: product.price,
        imageUrl: product.imageUrl,
        id: json.decode(response.body)['name'],
      );
      _items.add(newProduct);
      notifyListeners();
    } catch (error) {
      print(error);
      throw error;
    }
  }

  Future<void> updateProduct(String id, Product newProduct) async {
    final prodIndex = _items.indexWhere((prod) => prod.id == id);
    if (prodIndex >= 0) {
      final url =
          'https://flutter-update-71536-default-rtdb.firebaseio.com/products/$id.json?auth=$authToken';
      await http.patch(
        Uri.parse(url),
        body: json.encode({
          'title': newProduct.title,
          'description': newProduct.description,
          'imageUrl': newProduct.imageUrl,
          'price': newProduct.price,
        }),
      );
      _items[prodIndex] = newProduct;
      notifyListeners();
    } else {
      print('...');
    }
  }

  Future<void> deleteProduct(String id) async {
    final url =
        'https://flutter-update-71536-default-rtdb.firebaseio.com/products/$id.json?auth=$authToken';
    final existingProductIndex = _items.indexWhere((prod) => prod.id == id);
    Product? existingProduct = _items[existingProductIndex];
    _items.removeAt(existingProductIndex);
    notifyListeners();
    final response = await http.delete(Uri.parse(url));
    if (response.statusCode >= 400) {
      _items.insert(existingProductIndex, existingProduct);
      notifyListeners();
      throw HttpException('Could not delete product!');
    }
    existingProduct = null as Product?;
  }
}
