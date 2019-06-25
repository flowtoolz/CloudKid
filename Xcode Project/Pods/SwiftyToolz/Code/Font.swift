public enum Font
{
    case system(size: Int, weight: Weight)
    
    public enum Weight
    {
        case ultraLight, thin, light, regular, medium, semibold, bold, system
    }
    
    case named(name: String, size: Int)
}
