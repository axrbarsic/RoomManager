import Foundation
import SwiftUI
import Combine

/// Монитор производительности приложения
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    // MARK: - Performance Metrics
    @Published var fps: Double = 0
    @Published var memoryUsage: Double = 0 // MB
    @Published var metalUsage: Double = 0 // %
    @Published var cpuUsage: Double = 0 // %
    
    // MARK: - Monitoring State
    @Published var isMonitoring = false
    private var displayLink: CADisplayLink?
    private var frameCount = 0
    private var lastTimestamp: CFTimeInterval = 0
    
    // MARK: - Performance Tracking
    private var renderingErrors: [PerformanceEvent] = []
    private var memoryWarnings: [PerformanceEvent] = []
    private var slowOperations: [PerformanceEvent] = []
    
    private init() {
        setupNotifications()
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Interface
    func startMonitoring() {
        guard AppConfiguration.Debug.enablePerformanceMonitoring else { return }
        
        isMonitoring = true
        startFPSMonitoring()
        startMemoryMonitoring()
    }
    
    func stopMonitoring() {
        isMonitoring = false
        displayLink?.invalidate()
        displayLink = nil
    }
    
    // MARK: - Performance Tracking
    func trackRenderingError(_ error: Error, context: String = "") {
        let event = PerformanceEvent(
            type: .renderingError,
            timestamp: Date(),
            description: error.localizedDescription,
            context: context
        )
        renderingErrors.append(event)
        
        // Удаляем старые события (храним только последние 10)
        if renderingErrors.count > 10 {
            renderingErrors.removeFirst(renderingErrors.count - 10)
        }
        
        if AppConfiguration.Debug.enableVerboseLogging {
            print("🔴 Rendering Error: \(error.localizedDescription) | Context: \(context)")
        }
    }
    
    func trackSlowOperation<T>(_ operation: () throws -> T, threshold: TimeInterval = 0.1, name: String) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        if duration > threshold {
            let event = PerformanceEvent(
                type: .slowOperation,
                timestamp: Date(),
                description: "\(name) took \(String(format: "%.3f", duration))s",
                context: name
            )
            slowOperations.append(event)
            
            if slowOperations.count > 20 {
                slowOperations.removeFirst(slowOperations.count - 20)
            }
            
            if AppConfiguration.Debug.enableVerboseLogging {
                print("⚠️ Slow Operation: \(name) took \(String(format: "%.3f", duration))s")
            }
        }
        
        return result
    }
    
    // MARK: - Memory Management
    func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        
        return 0
    }
    
    // MARK: - Performance Recommendations
    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if fps < 45 {
            recommendations.append("Низкий FPS: рассмотрите отключение Metal эффектов")
        }
        
        if memoryUsage > 150 {
            recommendations.append("Высокое использование памяти: проверьте утечки")
        }
        
        if renderingErrors.count > 3 {
            recommendations.append("Частые ошибки рендеринга: переключитесь на упрощенный режим")
        }
        
        if slowOperations.filter({ $0.timestamp.timeIntervalSinceNow > -60 }).count > 5 {
            recommendations.append("Медленные операции: оптимизируйте вычисления")
        }
        
        return recommendations
    }
    
    // MARK: - Private Methods
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMetalError),
            name: NSNotification.Name("MetalRenderingError"),
            object: nil
        )
    }
    
    private func startFPSMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func startMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isMonitoring else { return }
            
            DispatchQueue.main.async {
                self.memoryUsage = self.getCurrentMemoryUsage()
            }
        }
    }
    
    @objc private func updateFPS() {
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        
        if lastTimestamp > 0 {
            let deltaTime = currentTime - lastTimestamp
            if deltaTime >= 1.0 {
                fps = Double(frameCount) / deltaTime
                frameCount = 0
                lastTimestamp = currentTime
            }
        } else {
            lastTimestamp = currentTime
        }
    }
    
    @objc private func handleMemoryWarning() {
        let event = PerformanceEvent(
            type: .memoryWarning,
            timestamp: Date(),
            description: "Memory warning received",
            context: "System"
        )
        memoryWarnings.append(event)
        
        if memoryWarnings.count > 5 {
            memoryWarnings.removeFirst(memoryWarnings.count - 5)
        }
        
        if AppConfiguration.Debug.enableVerboseLogging {
            print("⚠️ Memory Warning: \(memoryUsage)MB")
        }
    }
    
    @objc private func handleMetalError(_ notification: Notification) {
        let error = notification.object as? Error ?? NSError(domain: "Metal", code: -1)
        trackRenderingError(error, context: "Metal Rendering")
    }
}

// MARK: - Performance Event
struct PerformanceEvent {
    let type: EventType
    let timestamp: Date
    let description: String
    let context: String
    
    enum EventType {
        case renderingError
        case memoryWarning
        case slowOperation
        case metalError
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Performance Extensions
extension View {
    func trackPerformance<T>(operation: @escaping () -> T, name: String) -> T {
        return PerformanceMonitor.shared.trackSlowOperation(operation, name: name)
    }
    
    func monitorPerformance() -> some View {
        self.onAppear {
            if AppConfiguration.Debug.enablePerformanceMonitoring {
                PerformanceMonitor.shared.startMonitoring()
            }
        }
        .onDisappear {
            PerformanceMonitor.shared.stopMonitoring()
        }
    }
} 