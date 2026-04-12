import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // 1. Объявляем хранилище внутри класса
  final _storage = const FlutterSecureStorage();

  // 2. Настраиваем Dio
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://127.0.0.1:8000/api/',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );

  // Метод логина
  Future<bool> login(String username, String password) async {
    try {
      final response = await _dio.post(
        'token/',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        await _storage.write(
          key: 'access_token',
          value: response.data['access'],
        );
        await _storage.write(
          key: 'refresh_token',
          value: response.data['refresh'],
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Метод регистрации
  Future<bool> registerCompany({
    required String companyName,
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        'users/register/',
        data: {
          "company_name": companyName,
          "username": username,
          "email": email,
          "password": password,
        },
      );
      return response.statusCode == 201;
    } catch (e) {
      print("Ошибка регистрации: $e");
      return false;
    }
  }

  // Получение списка документов
  Future<List> getDocuments() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await _dio.get(
        'documents/all/',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      // Проверяем структуру ответа (зависит от твоего Django)
      if (response.data is Map) {
        return response.data['documents'] ?? [];
      }
      return response.data as List;
    } catch (e) {
      print("Ошибка получения документов: $e");
      return [];
    }
  }

  // Получение статистики (для главного экрана)
  Future<Map<String, dynamic>> getStats() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await _dio.get(
        'documents/stats/',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print("Ошибка статистики: $e");
      return {
        "total_docs": 0,
        "pending_docs": 0,
        "archived_docs": 0,
        "user_name": "Error",
        "user_role": "N/A",
      };
    }
  }

  Future<bool> createDocument(String title, PlatformFile file) async {
    try {
      final token = await _storage.read(key: 'access_token');

      // Подготовка данных для отправки
      FormData formData = FormData.fromMap({
        "title": title,
        "file": await MultipartFile.fromBytes(file.bytes!, filename: file.name),
      });

      final response = await _dio.post(
        'documents/create/',
        data: formData,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      return response.statusCode == 201;
    } catch (e) {
      print("Ошибка при создании документа: $e");
      return false;
    }
  }

  // Вспомогательные методы
  Future<String?> getToken() async => await _storage.read(key: 'access_token');

  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
