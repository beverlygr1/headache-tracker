import '../../../core/api/api_client.dart';

class MedicationsApi {
  MedicationsApi(this._client);
  final ApiClient _client;
  Future<List<String>> search(String query) async {
    final response = await _client.get<List<dynamic>>('/medications/catalog',
        queryParameters: {'query': query});
    return (response.data ?? const []).cast<String>();
  }

  Future<String> addCustom(String name) async {
    final response = await _client.post<Map<String, dynamic>>('/medications',
        data: {'name': name.trim()});
    return response.data!['name'] as String;
  }
}
