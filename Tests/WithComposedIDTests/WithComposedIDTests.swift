import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(WithCompositeIDMacros)
import WithCompositeIDMacros

let testMacros: [String: Macro.Type] = [
    "WithCompositeID": WithCompositeIDMacro.self,
]
#endif

final class WithCompositeIDTests: XCTestCase {
    func testKeyPaths() throws {
        #if canImport(WithCompositeIDMacros)
        assertMacroExpansion(
            """
            @WithCompositeID(using: \\.$customer, \\.$id)
            final class MyEntity: Model {
                @Parent(key: "customer_id")
                var customer: Customer

                @ID(custom: "id", generatedBy: .database)
                var id: Int?
            
                var prop: String
            }
            """,
            expandedSource: """
            final class MyEntity: Model {
                @Parent(key: "customer_id")
                var customer: Customer

                @ID(custom: "id", generatedBy: .database)
                var id: Int?
            
                var prop: String

                final class Composite: Model {
                    final class IDValue: Fields , Hashable {
                        @Parent(key: "customer_id") var customer: Customer
                        @Field(key: "id") var id: Int
                        required init() {
                        }
                        convenience init(customer: Customer.IDValue , id: Int?) {
                            self.init()
                            self.customer.id = customer
                            if let value = id {
                                self.id = value
                            }
                        }
                        func hash(into hasher: inout Hasher) {
                            hasher.combine(try! self.customer.requireID())
                            hasher.combine(self.id)
                        }
                        static func ==(lhs: IDValue, rhs: IDValue) -> Bool {
                            (try! lhs.customer.requireID(), lhs.id) == (try! rhs.customer.requireID(), rhs.id)
                        }
                    }
                    @CompositeID()
                    var id: IDValue?
                    var prop: String
                    var flat: MyEntity {
                        let flat = MyEntity()
                        if let id = self.id {
                            flat.customer = id.customer
                            flat.id = id.id
                        }
                        flat.prop = self.prop
                        return flat
                    }
                }

                var compositeID: Composite.IDValue {
                    let id = Composite.IDValue()
                    id.customer = self.customer
                    if let value = self.id {
                        id.id = value
                    }
                    return id
                }

                var composite: Composite {
                    let composite = Composite()
                    composite.id = self.compositeID
                    composite.prop = self.prop
                    return composite
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    func testProps() throws {
        #if canImport(WithCompositeIDMacros)
        assertMacroExpansion(
            """
            @WithCompositeID(using: "$customer", "$id")
            final class MyEntity: Model {
                @Parent(key: "customer_id")
                var customer: Customer

                @ID(custom: "id", generatedBy: .database)
                var id: Int?
            
                var prop: String
            
                var prop2: Int {
                    didSet {
                    }
                }

                var calc1: Int { 1 }
                var calc2: Int { get { 2 } }
                var calc3: Int { get throws { 3 } }
                var calc3: Int { get { 3 } set { _ = newValue }}
                var calc4: String { _read { self.prop } }
            }
            """,
            expandedSource: """
            final class MyEntity: Model {
                @Parent(key: "customer_id")
                var customer: Customer

                @ID(custom: "id", generatedBy: .database)
                var id: Int?
            
                var prop: String
            
                var prop2: Int {
                    didSet {
                    }
                }

                var calc1: Int { 1 }
                var calc2: Int { get { 2 } }
                var calc3: Int { get throws { 3 } }
                var calc3: Int { get { 3 } set { _ = newValue }}
                var calc4: String { _read { self.prop } }

                final class Composite: Model {
                    final class IDValue: Fields , Hashable {
                        @Parent(key: "customer_id") var customer: Customer
                        @Field(key: "id") var id: Int
                        required init() {
                        }
                        convenience init(customer: Customer.IDValue , id: Int?) {
                            self.init()
                            self.customer.id = customer
                            if let value = id {
                                self.id = value
                            }
                        }
                        func hash(into hasher: inout Hasher) {
                            hasher.combine(try! self.customer.requireID())
                            hasher.combine(self.id)
                        }
                        static func ==(lhs: IDValue, rhs: IDValue) -> Bool {
                            (try! lhs.customer.requireID(), lhs.id) == (try! rhs.customer.requireID(), rhs.id)
                        }
                    }
                    @CompositeID()
                    var id: IDValue?
                    var prop: String
                    var prop2: Int {
                            didSet {
                            }
                        }
                    var calc1: Int {
                        1
                    }
                    var calc2: Int {
                        get {
                            2
                        }
                    }
                    var calc3: Int {
                        get throws {
                            3
                        }
                    }
                    var calc3: Int {
                        get {
                            3
                        }
                        set {
                            _ = newValue
                        }
                    }
                    var calc4: String {
                        _read {
                            self.prop
                        }
                    }
                    var flat: MyEntity {
                        let flat = MyEntity()
                        if let id = self.id {
                            flat.customer = id.customer
                            flat.id = id.id
                        }
                        flat.prop = self.prop
                        flat.prop2 = self.prop2
                        return flat
                    }
                }

                var compositeID: Composite.IDValue {
                    let id = Composite.IDValue()
                    id.customer = self.customer
                    if let value = self.id {
                        id.id = value
                    }
                    return id
                }

                var composite: Composite {
                    let composite = Composite()
                    composite.id = self.compositeID
                    composite.prop = self.prop
                    composite.prop2 = self.prop2
                    return composite
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    func testNoID() throws {
        #if canImport(WithCompositeIDMacros)
        assertMacroExpansion(
            """
            @WithCompositeID
            final class MyEntity: Model {
                @WrapCompositeID
                @Parent(key: "customer_id")
                var customer: Customer

                @WrapCompositeID
                @Parent(key: "instance_id")
                var instance: Instance

                var prop: String
            }
            """,
            expandedSource: """
            final class MyEntity: Model {
                @WrapCompositeID
                @Parent(key: "customer_id")
                var customer: Customer

                @WrapCompositeID
                @Parent(key: "instance_id")
                var instance: Instance
            
                var prop: String

                final class IDValue: Fields , Hashable {
                    @Parent(key: "customer_id") var customer: Customer
                    @Parent(key: "instance_id") var instance: Instance
                    required init() {
                    }
                    convenience init(customer: Customer.IDValue , instance: Instance.IDValue) {
                        self.init()
                        self.customer.id = customer
                        self.instance.id = instance
                    }
                    func hash(into hasher: inout Hasher) {
                        hasher.combine(try! self.customer.requireID())
                        hasher.combine(try! self.instance.requireID())
                    }
                    static func ==(lhs: IDValue, rhs: IDValue) -> Bool {
                        (try! lhs.customer.requireID(), try! lhs.instance.requireID()) == (try! rhs.customer.requireID(), try! rhs.instance.requireID())
                    }
                }

                typealias WrapCompositeID<T> = WrapCompositeIDProperty<MyEntity, T>

                @CompositeID()
                var id: IDValue?
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
