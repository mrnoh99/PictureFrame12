import UIKit
import CoreLocation

extension Notification.Name {
    static let weatherDidUpdate = Notification.Name("weatherDidUpdate")
}

struct WeatherInfo {
    let temperature: Double
    let symbolName: String
    var temperatureString: String { return "\(Int(temperature.rounded()))°C" }
}

/// Weather service using Open-Meteo (free, no API key required).
final class WeatherManager: NSObject {

    static let shared = WeatherManager()

    private(set) var currentWeather: WeatherInfo?
    private var locationManager: CLLocationManager?
    private var lastLocation: CLLocation?
    private var refreshTimer: Timer?

    // MARK: - Lifecycle

    func start() {
        setupLocation()
        refreshTimer = Timer.scheduledTimer(timeInterval: 1800,
                                            target: self,
                                            selector: #selector(timerFired),
                                            userInfo: nil,
                                            repeats: true)
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        locationManager?.stopUpdatingLocation()
    }

    // MARK: - Private

    private func setupLocation() {
        let mgr = CLLocationManager()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager = mgr

        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .notDetermined:
            mgr.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            mgr.requestLocation()
        default:
            break
        }
    }

    @objc private func timerFired() {
        if let loc = lastLocation {
            fetchWithOpenMeteo(location: loc)
        } else {
            locationManager?.requestLocation()
        }
    }

    // MARK: - Open-Meteo

    private func fetchWithOpenMeteo(location: CLLocation) {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        guard let url = URL(string:
            "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true"
        ) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let jsonAny = try? JSONSerialization.jsonObject(with: data),
                  let json = jsonAny as? [String: Any],
                  let cw   = json["current_weather"] as? [String: Any],
                  let temp = cw["temperature"] as? Double,
                  let code = cw["weathercode"] as? Int else { return }
            let info = WeatherInfo(temperature: temp,
                                   symbolName: WeatherManager.symbol(for: code))
            DispatchQueue.main.async { self?.publish(info) }
        }.resume()
    }

    private func publish(_ info: WeatherInfo) {
        currentWeather = info
        NotificationCenter.default.post(name: .weatherDidUpdate, object: self)
    }

    // WMO weather code -> internal symbol key
    private static func symbol(for code: Int) -> String {
        switch code {
        case 0:           return "sun.max"
        case 1:           return "cloud.sun"
        case 2, 3:        return "cloud"
        case 45, 48:      return "cloud.fog"
        case 51, 53, 55:  return "cloud.drizzle"
        case 56, 57:      return "cloud.sleet"
        case 61, 63, 65:  return "cloud.rain"
        case 66, 67:      return "cloud.sleet"
        case 71, 73, 75:  return "cloud.snow"
        case 77:          return "cloud.snow"
        case 80, 81, 82:  return "cloud.heavyrain"
        case 85, 86:      return "cloud.snow"
        case 95:          return "cloud.bolt"
        case 96, 99:      return "cloud.bolt.rain"
        default:          return "cloud"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
        manager.stopUpdatingLocation()
        fetchWithOpenMeteo(location: loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }
}
