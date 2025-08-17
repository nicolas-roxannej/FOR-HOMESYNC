import 'package:weather/weather.dart';

class WeatherService {
  static const String API_KEY = 'YOUR_API_KEY';
  final WeatherFactory wf = WeatherFactory(API_KEY);

  Future<Weather> getCurrentWeather(String city) async {
    Weather weather = await wf.currentWeatherByCityName(city);
    return weather;
  }
}