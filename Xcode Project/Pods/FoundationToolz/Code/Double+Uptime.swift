import Darwin.Mach

public extension Double
{
    static var uptimeMilliseconds: Double
    {
        return Double(uptimeNanoSeconds) / 1000000.0
    }
    
    static var uptimeNanoSeconds: UInt64
    {
        let ticks = mach_absolute_time()
        var timeBase = mach_timebase_info_data_t()
        mach_timebase_info(&timeBase)
        return ticks * UInt64(timeBase.numer) / UInt64(timeBase.denom)
    }
}
