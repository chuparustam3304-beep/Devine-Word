import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiQuranRepository {
  final String baseUrl;
  ApiQuranRepository({required this.baseUrl});

  Future<Ayah?> findByReference(String reference) async {
    final uri = Uri.parse('$baseUrl/.netlify/functions/verse?reference=${Uri.encodeComponent(reference)}');
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body);
    return Ayah.fromJson(json);
  }

  Future<List<Ayah>> loadDailyPool() async {
    final uri = Uri.parse('$baseUrl/.netlify/functions/verse?random=true');
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map<Ayah>((e) => Ayah.fromJson(e)).toList();
    }
    if (data is Map) return [Ayah.fromJson(data)];
    return [];
  }
}
