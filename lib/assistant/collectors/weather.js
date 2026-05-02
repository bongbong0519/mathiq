// 광주 날씨 수집 (OpenWeatherMap)
export async function getWeather() {
  try {
    const lat = 35.1595;  // 광주
    const lon = 126.8526;
    const apiKey = process.env.OPENWEATHER_API_KEY;

    const url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${apiKey}&units=metric&lang=kr`;

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Weather API error: ${response.status}`);
    }

    const data = await response.json();

    return {
      temp: Math.round(data.main.temp),
      tempMin: Math.round(data.main.temp_min),
      tempMax: Math.round(data.main.temp_max),
      description: data.weather[0].description,
      icon: getWeatherEmoji(data.weather[0].main),
      humidity: data.main.humidity,
      windSpeed: data.wind.speed,
    };
  } catch (error) {
    console.error('Weather fetch failed:', error);
    return null;
  }
}

function getWeatherEmoji(main) {
  const map = {
    Clear: '☀️',
    Clouds: '☁️',
    Rain: '🌧️',
    Drizzle: '🌦️',
    Thunderstorm: '⛈️',
    Snow: '❄️',
    Mist: '🌫️',
    Fog: '🌫️',
    Haze: '🌫️',
  };
  return map[main] || '🌤️';
}
