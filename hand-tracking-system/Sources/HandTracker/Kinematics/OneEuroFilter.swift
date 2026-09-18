import Foundation
import CoreGraphics

/// Low-pass filter with exponential smoothing
final class LowPassFilter {
    private var y: CGFloat?
    private var s: CGFloat?
    
    init() {}
    
    func filter(value: CGFloat, alpha: CGFloat) -> CGFloat {
        guard let s = self.s else {
            self.s = value
            return value
        }
        let result = alpha * value + (1.0 - alpha) * s
        self.s = result
        return result
    }
    
    var lastValue: CGFloat? {
        return s
    }
    
    func reset() {
        s = nil
        y = nil
    }
}

/// 1€ Filter (One Euro Filter) for noise reduction and jitter suppression in real-time tracking
/// Casiez, G., Roussel, N. and Vogel, D. (2012). 1€ Filter: A Simple Speed-based Low-pass Filter for Noisy Input in HCI.
public final class OneEuroFilter {
    private var minCutoff: CGFloat
    private var beta: CGFloat
    private var dCutoff: CGFloat
    
    private let xFilter = LowPassFilter()
    private let dxFilter = LowPassFilter()
    private var lastTime: TimeInterval?
    
    public init(minCutoff: CGFloat = 1.0, beta: CGFloat = 0.007, dCutoff: CGFloat = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }
    
    private func alpha(rate: CGFloat, cutoff: CGFloat) -> CGFloat {
        let tau = 1.0 / (2.0 * .pi * cutoff)
        let te = 1.0 / rate
        return 1.0 / (1.0 + tau / te)
    }
    
    public func filter(value: CGFloat, timestamp: TimeInterval) -> CGFloat {
        guard let prevTime = lastTime else {
            lastTime = timestamp
            return xFilter.filter(value: value, alpha: 1.0)
        }
        
        let dt = CGFloat(max(timestamp - prevTime, 0.0001))
        lastTime = timestamp
        let rate = 1.0 / dt
        
        // Estimate derivative
        let prevX = xFilter.lastValue ?? value
        let dx = (value - prevX) * rate
        let edx = dxFilter.filter(value: dx, alpha: alpha(rate: rate, cutoff: dCutoff))
        
        // Dynamic cutoff frequency based on speed
        let cutoff = minCutoff + beta * abs(edx)
        return xFilter.filter(value: value, alpha: alpha(rate: rate, cutoff: cutoff))
    }
    
    public func reset() {
        xFilter.reset()
        dxFilter.reset()
        lastTime = nil
    }
}

/// 2D point filter combining two OneEuroFilters
public final class PointFilter {
    private let xFilter: OneEuroFilter
    private let yFilter: OneEuroFilter
    
    public init(minCutoff: CGFloat = 1.2, beta: CGFloat = 0.008) {
        self.xFilter = OneEuroFilter(minCutoff: minCutoff, beta: beta)
        self.yFilter = OneEuroFilter(minCutoff: minCutoff, beta: beta)
    }
    
    public func filter(point: CGPoint, timestamp: TimeInterval) -> CGPoint {
        let fx = xFilter.filter(value: point.x, timestamp: timestamp)
        let fy = yFilter.filter(value: point.y, timestamp: timestamp)
        return CGPoint(x: fx, y: fy)
    }
    
    public func reset() {
        xFilter.reset()
        yFilter.reset()
    }
}
