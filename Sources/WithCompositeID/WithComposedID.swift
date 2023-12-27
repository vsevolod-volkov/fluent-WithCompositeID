@attached(member, names: named(Composite))
public macro WithCompositeID<T: AnyObject>(using: PartialKeyPath<T> ...) = #externalMacro(module: "WithCompositeIDMacros", type: "WithCompositeIDMacro")

@attached(member, names: named(Composite))
public macro WithCompositeID(using: String ...) = #externalMacro(module: "WithCompositeIDMacros", type: "WithCompositeIDMacro")
