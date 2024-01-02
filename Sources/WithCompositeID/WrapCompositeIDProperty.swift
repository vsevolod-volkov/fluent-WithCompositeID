import Fluent

@propertyWrapper
public struct WrapCompositeIDProperty<Instance, Property> where Instance: Model {
    public var wrappedValue: Property {
        get { fatalError("@WrapCompositeID property must be accessed under $id.") }
        set { fatalError("@WrapCompositeID property must be accessed under $id.") }
    }
    
    public init() {}
    public init(wrappedValue: Property) {
        fatalError("@WrapCompositeID property must be accessed under $id.")
    }
}

