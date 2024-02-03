//
//  TimeAgo.swift
//

import Foundation

/**
Convenient conversions for generating NSTimeIntervals for common values.
Note that because of the Magic of Swift™, integer literals will be converted
correctly, so `10.hours` will work.
*/
extension TimeInterval {

    public var milliseconds: TimeInterval {
        return seconds / 1000
    }

    public var seconds: TimeInterval {
        return self
    }

    public var minutes: TimeInterval {
        return seconds * 60
    }

    public var hours: TimeInterval {
        return minute * 60
    }

    public var days: TimeInterval {
        return hour * 24
    }

    public var weeks: TimeInterval {
        return days * 7
    }

    /// Warning: returns 30 days, nothing clever.
    public var months: TimeInterval {
        return days * 30
    }

    public var years: TimeInterval {
        return days * 365.25
    }

    // MARK: Convenient Aliases, so 1.week works

    public var second: TimeInterval {
        return seconds
    }

    public var minute: TimeInterval {
        return minutes
    }

    public var hour: TimeInterval {
        return hours
    }

    public var day: TimeInterval {
        return days
    }

    public var week: TimeInterval {
        return weeks
    }

    public var year: TimeInterval {
        return years
    }
}

extension TimeInterval {
    /// Returns a date from subtracting `self` from now
    public var ago: Date {
        return Date(timeIntervalSinceNow: -self)
    }

    /// Returns a date by adding `self` to now
    public var fromNow: Date {
        return Date(timeIntervalSinceNow: self)
    }

    /**
    
    e.g. 10.hours.since(1.week.ago) will return the date at
    1 week ago plus 10 hours.

    - parameter date: The date to add `self` to

    - returns: a date by adding self to the provided date
    (defaults to now)

    */
    func since(_ date: Date = Date()) -> Date {
        return date.addingTimeInterval(self)
    }

    /**
    e.g. 10.hours.until(1.week.ago) will return the date 10 hours
    before 1 week ago.

    - parameter date:

    - returns: a date by subtracting self from the provided date
    (defaults to now)
    */
    func until(_ date: Date = Date()) -> Date {
        return date.addingTimeInterval(-self)
    }
}

/**
The following functions allow mathematical operations on NSDate and 
NSTimeIntervalOptions, for example:

``if 1.week.ago < someDate {``
``someDate + 10.hours``
``someDate - 1.week.ago`` ==> returns the time between the two dates
*/

public func <(lhs: Date, rhs: Date) -> Bool {
    return lhs.compare(rhs) == ComparisonResult.orderedAscending
}

//public func ==(lhs: Date, rhs: Date) -> Bool {
//    return (lhs == rhs)
//}

public func +(lhs: Date, rhs: TimeInterval) -> Date {
    return lhs.addingTimeInterval(rhs)
}

//public func +=(lhs: inout Date, rhs: TimeInterval) {
//    lhs = lhs + rhs
//}

public func -(lhs: Date, rhs: Date) -> TimeInterval {
    return lhs.timeIntervalSince(rhs)
}

public func -(lhs: Date, rhs: TimeInterval) -> Date {
    return lhs.addingTimeInterval(-rhs)
}

//public func -=(lhs: inout Date, rhs: TimeInterval) {
//    lhs = lhs - rhs
//}
