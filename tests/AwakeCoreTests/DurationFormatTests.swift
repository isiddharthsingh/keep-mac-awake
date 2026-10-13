import Foundation
import Testing
@testable import AwakeCore

struct DurationFormatTests {
    @Test(arguments: [
        (6120.0, "1:42"),
        (6100.0, "1:42"),   // partial minutes round up
        (3599.0, "1:00"),   // 59m 59s rounds up into hours format
        (36000.0, "10:00"),
        (2520.0, "42m"),
        (1.0, "1m"),
        (0.0, "0m"),
    ])
    func menuBar(seconds: TimeInterval, expected: String) {
        #expect(DurationFormat.menuBar(seconds) == expected)
    }

    @Test(arguments: [
        (6138.0, "1:42:18"),
        (3600.0, "1:00:00"),
        (2538.0, "42:18"),
        (0.2, "0:01"),      // partial seconds round up so it hits 0:00 exactly at the end
        (0.0, "0:00"),
    ])
    func countdown(seconds: TimeInterval, expected: String) {
        #expect(DurationFormat.countdown(seconds) == expected)
    }
}
