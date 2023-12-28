@attached(member, names: named(Composite), named(composite))
public macro WithCompositeID<T: AnyObject>(using: PartialKeyPath<T> ...) = #externalMacro(module: "WithCompositeIDMacros", type: "WithCompositeIDMacro")

@attached(member, names: named(Composite), named(composite))
public macro WithCompositeID(using: String ...) = #externalMacro(module: "WithCompositeIDMacros", type: "WithCompositeIDMacro")
