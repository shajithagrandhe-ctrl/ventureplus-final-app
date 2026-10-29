import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

const usesBrowserCookies = true;
void configureDio(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}
