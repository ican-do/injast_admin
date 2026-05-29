/// تنظیمات نقشه و geocoding سرویس map.ir
/// مستندات تایل: https://help.map.ir/documentation/fluttersdk-installation/
class MapIrConfig {
  MapIrConfig._();

  /// توکن map.ir — بعداً در همین فایل قابل تغییر است.
  static const apiKey =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImp0aSI6ImEzNTIzMzg4OTNjNDVhMzM3NTIyMmVjMzczMGFkMzI4ZmY3MGM1MzNkNTlhZDQ0OTM2OGM5ZmVhMzYzNzJmMjM2M2MwMDY1YTg5ZGJhMzUxIn0.eyJhdWQiOiIxOTg0OCIsImp0aSI6ImEzNTIzMzg4OTNjNDVhMzM3NTIyMmVjMzczMGFkMzI4ZmY3MGM1MzNkNTlhZDQ0OTM2OGM5ZmVhMzYzNzJmMjM2M2MwMDY1YTg5ZGJhMzUxIiwiaWF0IjoxNzEzOTM4NTYzLCJuYmYiOjE3MTM5Mzg1NjMsImV4cCI6MTcxNjM1Nzc2Mywic3ViIjoiIiwic2NvcGVzIjpbImJhc2ljIl19.MgTmckk39Nh6g22xYYDPze7dRHn7iXuh3aItu8ShFG7CoWLLeM4DtqjLCn2BD-lCuBZVLs2XEj4BJiWgdxIsddt1XgQTePNzwrV24YmqnDDsiY7lkt5OrJBU0NWlQUo9ZdQPC-EDuUJDbW-CpgS9_yhQUW6GiywUBmILn25PbuCkQOw9IIUQcYWuttxRu9ZJCTygSc0JgOg-gKBVc_tkvocBY_Le7EGa7_TrP_Fwr6fU1JLgSz6zsDUe_MHJwq9kN6YtmMWapaIKiMwv-VM610M7g-mKnfD947hvg9p1E4qTPKyOSkpKWxkVQ1mv4MC1mjBwdFKrkSq73uaPtH_aYg';

  /// الگوی رسمی تایل raster map.ir برای flutter_map
  static String get tileUrlTemplate =>
      'https://map.ir/shiveh/xyz/1.0.0/Shiveh:Shiveh@EPSG:3857@png/{z}/{x}/{y}.png?x-api-key=$apiKey';

  static Map<String, String> get tileHeaders => {
        'x-api-key': apiKey,
        'User-Agent': userAgent,
        'Accept': 'image/png,image/jpeg,image/webp,image/*,*/*',
      };

  static Map<String, String> get apiHeaders => {
        'x-api-key': apiKey,
        'User-Agent': userAgent,
        'Accept': 'application/json',
      };

  static const geocodeTimeout = Duration(seconds: 10);
  static const userAgent = 'injast_admin/1.0';

  static const tileAttribution = '© map.ir';

  /// پشتیبان geocoding در صورت خطای map.ir
  static const neshanApiKey = String.fromEnvironment(
    'NESHAN_API_KEY',
    defaultValue: 'service.1c8e1ac2992643cfa931b8f52a6e0b39',
  );
}
