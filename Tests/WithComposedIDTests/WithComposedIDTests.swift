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
                        @Field(key: "id") var id: Int?
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

                var composite: Composite {
                    let composite = Composite()
                    composite.id = Composite.IDValue()
                    composite.id!.customer = self.customer
                    composite.id!.id = self.id
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
    func testNames() throws {
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
                        @Field(key: "id") var id: Int?
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

                var composite: Composite {
                    let composite = Composite()
                    composite.id = Composite.IDValue()
                    composite.id!.customer = self.customer
                    composite.id!.id = self.id
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
}
