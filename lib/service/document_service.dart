import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/vehicle_document.dart';

class DocumentService {
  static const _base = 'https://drcars-fyp-production.up.railway.app';

  /// Upload photo to server, returns the photo URL
  static Future<String?> uploadPhoto(File photo) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_base/documents/upload'),
      );
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        return jsonDecode(body)['url'] as String?;
      }
    } catch (e) {
      print('Photo upload error: $e');
    }
    return null;
  }

  /// Save document record to MongoDB
  static Future<bool> addDocument(Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/vehicle-documents'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// Get all documents for a user
  static Future<List<VehicleDocument>> getDocuments(String userId) async {
    try {
      final res = await http.get(Uri.parse('$_base/vehicle-documents/$userId'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => VehicleDocument.fromJson(e)).toList();
      }
    } catch (e) {
      print('Get documents error: $e');
    }
    return [];
  }

  /// Delete a document
  static Future<bool> deleteDocument(String id) async {
    try {
      final res = await http.delete(Uri.parse('$_base/vehicle-documents/$id'));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
