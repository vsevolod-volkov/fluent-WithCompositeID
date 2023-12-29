import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct WithCompositeIDMacro: MemberMacro {
    private struct FluentAttributeInfo {
        let referID: Bool
        let convert: (VariableDeclSyntax) -> VariableDeclSyntax
        
        init(referID: Bool = false, convert: @escaping (VariableDeclSyntax) -> VariableDeclSyntax = { $0 }) {
            self.referID = referID
            self.convert = convert
        }
    }
    private struct CompositeProperty {
        let fluentAttribute: (
            name: String,
            info: FluentAttributeInfo
        )
        let variable: VariableDeclSyntax
        let name: String
    }
    private static let fluentAttributes: [String: FluentAttributeInfo] = [
        "ID": .init {
            VariableDeclSyntax(
                attributes: .init($0.attributes.map {
                    if let attribute = $0.as(AttributeSyntax.self), attribute.attributeName.trimmedDescription == "ID" {
                        let key: String
                        
                        switch attribute.arguments {
                        case .argumentList(let argumentList):
                            if let argument = argumentList.first?.as(LabeledExprSyntax.self),
                               let label = argument.label?.trimmedDescription {
                                switch label {
                                case "custom":
                                    key = argument.expression.trimmedDescription
                                
                                default:
                                    fatalError("@WithCompositeID does not support @ID(\(label):)")
                                }
                            } else {
                                key = "\"id\""
                            }
                        default:
                            fatalError("@WithCompositeID can not obtain key field name from @ID() arguments.")
                        }
                        
                        return AttributeListSyntax.Element(AttributeSyntax("Field") {.init(
                            label: "key",
                            expression: ExprSyntax(stringLiteral: key)
                        )})
                    } else {
                        return $0
                    }
                }),
                modifiers: $0.modifiers,
                bindingSpecifier: $0.bindingSpecifier,
                bindings: $0.bindings
            )
        },
        "Field": .init(),
        "Parent": .init(referID: true),
        "CompositeParent": .init(referID: true),
    ]
    
    private static func usage() -> Never {
        fatalError("Must use @WithCompositeID(keys: ...).")
    }
    
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let declaration = declaration as? ClassDeclSyntax else {
            fatalError("@WithCompositeID may only be applied to classes.")
        }
        
        let adoptedProtocols: [String] = (declaration.inheritanceClause?.inheritedTypes.compactMap {
            guard let type = $0.type.as(IdentifierTypeSyntax.self),
                  case .identifier(let identifier) = type.name.tokenKind else {
                return nil
            }
            
            return identifier
        } ?? [])
        
        guard adoptedProtocols.contains("Model") else {
            fatalError("@WithCompositeID may only be applied to Model.")
        }
        
        guard let arguments = node.arguments,
              case .argumentList(let argumentList) = arguments,
              let firstArgument = argumentList.first,
              firstArgument.label?.trimmedDescription == "using" else {
            fatalError("@WithCompositeID requires using: argument.")
        }
        
        for index in argumentList.indices[argumentList.index(after: argumentList.startIndex)...] {
            if argumentList[index].label != nil {
                fatalError("@WithCompositeID requires exactly one argument whth \"using:\" label.")
            }
        }

        let compositeProperties = Set(argumentList.map { argument in
            var name: String
            
            if let keyPath = argument.expression.as(KeyPathExprSyntax.self) {
                guard keyPath.root?.trimmedDescription ?? declaration.name.trimmedDescription == declaration.name.trimmedDescription else {
                    fatalError("@WithCompositeID requeres uses: KeyPaths of type \(declaration.name).")
                }
                
                guard let component = keyPath.components.first?.component, keyPath.components.count == 1,
                      case .property(let property) = component,
                      property.declName.trimmedDescription.hasPrefix("$") else {
                    fatalError("@WithCompositeID supports only top-level $-prefixed property KeyPath arguments.")
                }
                
                name = property.declName.trimmedDescription
            } else if let string = argument.expression.as(StringLiteralExprSyntax.self) {
                guard string.segments.description.hasPrefix("$") else {
                    fatalError("@WithCompositeID supports only top-level $-prefixed property KeyPath arguments.")
                }
                
                name = string.segments.description
            } else {
                fatalError("@WithCompositeID requires either PartialKeyPath or string literal arguments.")
            }
            
            name.removeFirst()
            
            return name
        })
        
        var inner = declaration
        
        let nodeName = node.attributeName.trimmedDescription
        for i in inner.attributes.indices.reversed() {
            guard let name = inner.attributes[i].as(AttributeSyntax.self)?.attributeName.trimmedDescription else {
                continue
            }
            if name == nodeName {
                inner.attributes.remove(at: i)
            }
        }
        
        inner.name = "Composite"
        
        var allProperties: [String: FluentAttributeInfo] = [:]
        var compositeMembers: [CompositeProperty] = []
        var remainingMembers: [MemberBlockItemSyntax] = []
        
        func containsDisallowedAccessor(binding: PatternBindingSyntax) -> Bool {
            let disallowedAccessors: Set = ["get", "set", "_read", "_modify"]

            guard let accessors = binding.accessorBlock?.accessors.as(AccessorDeclListSyntax.self) else {
                return binding.accessorBlock?.accessors.is(CodeBlockItemListSyntax.self) == true
            }
            
            for accessor in accessors {
                if disallowedAccessors.contains(accessor.accessorSpecifier.trimmedDescription) {
                    return true
                }
            }
            return false
        }
        
        var remainingVariables: [VariableDeclSyntax] {
            remainingMembers.compactMap {
                $0.decl.as(VariableDeclSyntax.self)
            }.compactMap {
                var variable = $0
                variable.bindings = variable.bindings.filter {
                    $0.pattern.trimmedDescription != "schema" &&
                    !containsDisallowedAccessor(binding: $0)
                }
                return variable.bindings.isEmpty ? nil : variable
            }.filter {
                !$0.modifiers.contains(.init(name: "static")) &&
                $0.bindingSpecifier.trimmedDescription == "var"
            }
        }
        
        var member = inner.memberBlock.members.makeIterator()
        while let member = member.next() {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }
            
            let attributes = Set(variable.attributes.compactMap {
                $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription
            })
            
            let filteredAttributes = attributes.intersection(fluentAttributes.keys)
            
            if let fluentAttribute = filteredAttributes.first {
                guard filteredAttributes.count == 1 else {
                    fatalError("@WithCompositeID does not support multiple fluent attibutes for same property.")
                }

                for binding in variable.bindings {
                    allProperties[binding.pattern.trimmedDescription] = fluentAttributes[fluentAttribute]!
                }
                
                for binding in variable.bindings {
                    var variable = variable
                 
                    variable.bindingSpecifier.leadingTrivia = ""
                    variable.bindingSpecifier.trailingTrivia = ""
                    variable.leadingTrivia = ""
                    variable.trailingTrivia = ""
                    variable.modifiers.leadingTrivia = ""
                    variable.modifiers.trailingTrivia = ""
                    for i in variable.modifiers.indices {
                        variable.modifiers[i].leadingTrivia = ""
                        variable.modifiers[i].trailingTrivia = ""
                    }
                    variable.bindingSpecifier.leadingTrivia = ""
                    variable.bindingSpecifier.trailingTrivia = ""
                    variable.bindings.leadingTrivia = ""
                    variable.bindings.trailingTrivia = ""
                    variable.bindings = [variable.bindings.last!]
                    variable.bindings[variable.bindings.startIndex].leadingTrivia = ""
                    variable.bindings[variable.bindings.startIndex].trailingTrivia = ""
                    variable.bindings[variable.bindings.startIndex].pattern = binding.pattern
                    variable.bindings[variable.bindings.startIndex].pattern.leadingTrivia = ""
                    variable.bindings[variable.bindings.startIndex].pattern.trailingTrivia = ""

                    if compositeProperties.contains(binding.pattern.trimmedDescription) {
                        compositeMembers.append(.init(
                            fluentAttribute: (
                                name: fluentAttribute,
                                info: fluentAttributes[fluentAttribute]!
                            ),
                            variable: variable,
                            name: binding.pattern.trimmedDescription
                        ))
                    } else {
                        remainingMembers.append(MemberBlockItemSyntax(decl: variable))
                    }
                }
            } else {
                remainingMembers.append(member)
            }
        }
        
        guard compositeProperties.subtracting(allProperties.keys).isEmpty else {
            fatalError("Wrong @WithCompositeID KeyPath arguments: \(compositeProperties.subtracting(allProperties.keys).sorted().map{ "\\.$\($0)" }.joined(separator: ", ")).")
        }
        
        func scalarValue(ofProperty property: String, withPrefix prefix: String = "") -> String {
            if allProperties[property]!.referID {
                "try! \(prefix)\(property).requireID()"
            } else {
                "\(prefix)\(property)"
            }
        }
        
        let idValue = ClassDeclSyntax(
            modifiers: [.init(name: "final")],
            classKeyword: "class",
            name: "IDValue",
            inheritanceClause: .init(inheritedTypes: .init([
                .init(type: TypeSyntax(stringLiteral: "Fields"), trailingComma: ","),
                .init(type: TypeSyntax(stringLiteral: "Hashable")),
            ])),
            memberBlock: .init(members: .init(compositeMembers.map {
                MemberBlockItemSyntax(decl: $0.fluentAttribute.info.convert($0.variable))
            } + [.init(decl: FunctionDeclSyntax(
                funcKeyword: "func",
                name: "hash",
                signature: .init(parameterClause: .init(parameters: ["into hasher: inout Hasher"])),
                body: .init(statements: .init(compositeMembers.map {
                    $0.variable
                }.map {
                    $0.bindings.compactMap {
                        CodeBlockItemSyntax(item: .expr("hasher.combine(\(raw: scalarValue(ofProperty: $0.pattern.trimmedDescription, withPrefix: "self.")))"))
                    }
                }.joined()
                ))
            )), .init(decl: FunctionDeclSyntax(
                modifiers: [.init(name: "static")],
                funcKeyword: "func",
                name: "==",
                signature: .init(parameterClause: .init(
                    parameters: ["lhs: IDValue,", "rhs: IDValue"]),
                    returnClause: .init(type: TypeSyntax(stringLiteral: "Bool"))
                ),
                body: .init(statements: [CodeBlockItemSyntax(item: .expr("""
                    (\(raw: compositeMembers.compactMap {
                        $0.variable
                    }.map {
                        $0.bindings.compactMap {
                            "\(scalarValue(ofProperty: $0.pattern.trimmedDescription, withPrefix: "lhs."))"
                        }
                    }.joined().joined(separator: ", "))) == (\(raw: compositeMembers.compactMap {
                        $0.variable
                    }.map {
                        $0.bindings.compactMap {
                            "\(scalarValue(ofProperty: $0.pattern.trimmedDescription, withPrefix: "rhs."))"
                        }
                    }.joined().joined(separator: ", ")))
                    """
                ))])
            ))]))
        )
        
        inner.memberBlock.members = .init([.init(decl: idValue)])
        inner.memberBlock.members.append(.init(decl: try VariableDeclSyntax("""
            @CompositeID()
            var id: IDValue?
            """
        )))
        inner.memberBlock.members.append(contentsOf: remainingMembers.map {
            guard var variable = $0.decl.as(VariableDeclSyntax.self) else { return $0 }
            
            variable.leadingTrivia = ""
            variable.trailingTrivia = ""

            return .init(decl: variable.as(DeclSyntax.self)!)
        })
        
        inner.memberBlock.members.append( .init(decl: try VariableDeclSyntax("""
            var flat: \(declaration.name) {
                let flat = \(declaration.name)()
                if let id = self.id {
                \(raw: compositeMembers.map {
                    "    flat.\($0.variable.bindings.first!.pattern) = id.\($0.fluentAttribute.info.convert($0.variable).bindings.first!.pattern)"
                }.joined(separator: "\n    "))
                }
                \(raw: remainingVariables.map {
                    "flat.\($0.bindings.first!.pattern) = self.\($0.bindings.first!.pattern)"
                }.joined(separator: "\n"))
                return flat
            }
            """
        )))

        return [
            inner.as(DeclSyntax.self)!,
            """
            var composite: Composite {
                let composite = Composite()
                composite.id = Composite.IDValue()
                \(raw: compositeMembers.map {
                    "composite.id!.\($0.fluentAttribute.info.convert($0.variable).bindings.first!.pattern) = self.\($0.variable.bindings.first!.pattern)"
                }.joined(separator: "\n"))
                \(raw: remainingVariables.map {
                    "composite.\($0.bindings.first!.pattern) = self.\($0.bindings.first!.pattern)"
                }.joined(separator: "\n"))
                return composite
            }
            """,
        ]
    }
        
}

@main
struct WithCompositeIDPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        WithCompositeIDMacro.self,
    ]
}
