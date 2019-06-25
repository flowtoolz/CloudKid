public extension Array
{
    func splitIntoSlices(ofSize size: Int) -> [ArraySlice<Element>]
    {
        guard size > 0 else { return [] }
        
        var result = [ArraySlice<Element>]()
        
        var sliceStart = -1
        var sliceEnd = -1
        
        while sliceEnd < count - 1
        {
            sliceStart = sliceEnd + 1
            sliceEnd = Swift.min(sliceEnd + size, count - 1)
            
            result.append(self[sliceStart ... sliceEnd])
        }
        
        return result
    }
    
    func forEachIndex(_ body: (_ element: Element,
                               _ index: Int) throws -> Void) rethrows
    {
        for index in 0 ..< count
        {
            try body(self[index], index)
        }
    }
    
    subscript(_ indexes: [Int]) -> [Element]
    {
        var result = [Element]()
        
        for index in indexes
        {
            guard isValid(index: index) else { continue }
            
            result.append(self[index])
        }
        
        return result
    }
    
    mutating func moveElement(from: Int, to: Int) -> Bool
    {
        guard from != to, isValid(index: from), isValid(index: to) else
        {
            return false
        }
        
        insert(remove(at: from), at: to)
        
        return true
    }
    
    mutating func limit(to maxCount: Int)
    {
        guard maxCount >= 0 else { return }
        
        removeLast(Swift.max(0, count - maxCount))
    }
    
    mutating func remove(where shouldRemove: (Element) -> Bool)
    {
        var index = count - 1
        
        while index >= 0
        {
            if shouldRemove(self[index]) { remove(at: index) }
            
            index -= 1
        }
    }
    
    func isValid(index: Int?) -> Bool
    {
        guard let index = index else { return false }
        
        return index >= 0 && index < count
    }
}
