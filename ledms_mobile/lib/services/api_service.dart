import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();

  final Dio _dio = Dio(
    BaseOptions(
      // Подсказка: если тестируешь на реальном Android-телефоне,
      // замени 127.0.0.1 на IP ПК в Wi‑Fi (например, 192.168.1.10) и открой порт 8000 в файрволе.
      baseUrl: 'http://127.0.0.1:8000/api/',
      connectTimeout: const Duration(seconds: 30),
      // Обычные GET — короткий таймаут; для OCR см. createDocument (отдельный receiveTimeout).
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // --- Метод логина ---
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

  // --- Метод регистрации ---
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

  // --- Получить профиль ТЕКУЩЕГО пользователя ---
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await _dio.get(
        'users/me/',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print("Ошибка профиля: $e");
      throw Exception('Failed to load profile');
    }
  }

  // --- Получить список сотрудников ---
  // --- Получить список сотрудников ---
  Future<List> getEmployees() async {
    try {
      final token = await _storage.read(key: 'access_token');
      // ИСПРАВЛЕНО: Добавлен префикс users/ чтобы путь стал /api/users/employees/
      final response = await _dio.get(
        'users/employees/',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return response.data as List;
    } catch (e) {
      print("Ошибка загрузки сотрудников: $e");
      throw Exception('Failed to load employees');
    }
  }

  // --- НОВЫЙ МЕТОД: Добавить сотрудника с ролью ---
  Future<bool> addEmployee(Map<String, dynamic> userData) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await _dio.post(
        'users/employees/',
        data: userData,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return response.statusCode == 201;
    } catch (e) {
      print("Ошибка добавления сотрудника: $e");
      return false;
    }
  }

  // --- Получить данные компании (название, логотип, ИНН) ---
  Future<Map<String, dynamic>> getCompanyDetail() async {
    final token = await _storage.read(key: 'access_token');
    final response = await _dio.get(
      'company/',
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
    return response.data as Map<String, dynamic>;
  }

  // --- Обновить данные компании (только для Owner) ---
  Future<bool> updateCompany({String? name, XFile? logoFile, XFile? bannerFile}) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final fields = <String, dynamic>{};
      if (name != null) fields['name'] = name;
      if (logoFile != null) {
        final bytes = await logoFile.readAsBytes();
        fields['logo'] = MultipartFile.fromBytes(bytes, filename: logoFile.name);
      }
      if (bannerFile != null) {
        final bytes = await bannerFile.readAsBytes();
        fields['banner'] = MultipartFile.fromBytes(bytes, filename: bannerFile.name);
      }
      final response = await _dio.patch(
        'company/',
        data: FormData.fromMap(fields),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Ошибка обновления компании: $e");
      return false;
    }
  }

  // --- Обновить данные сотрудника (email / role / password) ---
  Future<bool> updateEmployee(int userId, Map<String, dynamic> data) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await _dio.patch(
        'users/$userId/update/',
        data: data,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Ошибка обновления сотрудника: $e");
      return false;
    }
  }

  Future<bool> deleteEmployee(int userId) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await _dio.delete(
        'users/$userId/delete/', // Убедись, что путь в urls.py совпадает
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print("Ошибка при удалении сотрудника: $e");
      return false;
    }
  }

  // --- Получение списка документов ---
  Future<List> getDocuments({Map<String, dynamic>? filters}) async {
    // Добавили аргумент {Map<String, dynamic>? filters}
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await _dio.get(
        'documents/all/',
        queryParameters: filters, // Теперь фильтры передаются правильно
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (response.data is List) return response.data;
      if (response.data is Map) {
        if (response.data.containsKey('results'))
          return response.data['results'];
        if (response.data.containsKey('documents'))
          return response.data['documents'];
      }
      return [];
    } catch (e) {
      print("Ошибка документов: $e");
      return [];
    }
  }

  // --- Статистика ---
  Future<Map<String, dynamic>> getStats() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await _dio.get(
        'documents/stats/',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {
        "total_docs": 0,
        "pending_docs": 0,
        "archived_docs": 0,
        "user_name": "Error",
        "user_role": "N/A",
      };
    }
  }

  // --- Создание документа ---
  Future<dynamic> createDocument(
    String title,
    PlatformFile file, {
    String? supplier,
    double? amount,
    String? category,
  }) async {
    try {
      final token = await _storage.read(key: 'access_token');

      FormData formData = FormData.fromMap({
        "title": title,
        "supplier": supplier ?? "",
        "amount": amount?.toString() ?? "",
        "category": category ?? "other",
        "file": MultipartFile.fromBytes(file.bytes!, filename: file.name),
      });

      // OCR + первый запуск: скачивание весов моделей на сервере может занять минуты.
      final response = await _dio.post(
        'documents/create/',
        data: formData,
        options: Options(
          headers: {"Authorization": "Bearer $token"},
          receiveTimeout: const Duration(minutes: 6),
          sendTimeout: const Duration(minutes: 3),
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Критическая ошибка создания/OCR: $e");
      return null;
    }
  }

  // --- Обновление профиля (PATCH multipart) ---
  Future<Map<String, dynamic>?> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? bio,
    String? birthday,
    XFile? avatarFile,
    XFile? bannerFile,
  }) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final fields = <String, dynamic>{};
      if (firstName != null) fields['first_name'] = firstName;
      if (lastName != null) fields['last_name'] = lastName;
      if (email != null) fields['email'] = email;
      if (phone != null) fields['phone'] = phone;
      if (bio != null) fields['bio'] = bio;
      if (birthday != null) fields['birthday'] = birthday;

      if (avatarFile != null) {
        final bytes = await avatarFile.readAsBytes();
        fields['avatar'] = MultipartFile.fromBytes(bytes, filename: avatarFile.name);
      }
      if (bannerFile != null) {
        final bytes = await bannerFile.readAsBytes();
        fields['profile_banner'] = MultipartFile.fromBytes(bytes, filename: bannerFile.name);
      }

      final response = await _dio.patch(
        'users/me/',
        data: FormData.fromMap(fields),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // --- Смена пароля ---
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final token = await _storage.read(key: 'access_token');
    await _dio.post(
      'users/me/change-password/',
      data: {
        'old_password': oldPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  // --- Вспомогательные методы ---
  Future<String?> getToken() async => await _storage.read(key: 'access_token');

  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
