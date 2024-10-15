import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftDiagnostics
import SwiftBasicFormat
@_spi(ExperimentalLanguageFeature) import SwiftSyntaxMacros

@_spi(ExperimentalLanguageFeature)
public struct TransformBodyMacro: BodyMacro {
        
    public static var formatMode: FormatMode { .disabled }
    
    public static func expansion(of node: AttributeSyntax, providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax, in context: some MacroExpansionContext) throws -> [CodeBlockItemSyntax] {
                
        guard let builder = node.attributeName.as(IdentifierTypeSyntax.self)?.genericArgumentClause?.arguments.first?.trimmedDescription else {
            return []
        }
        
        var buildMethods: [String] = []
        
        node.arguments?.as(LabeledExprListSyntax.self)?.forEach {
            if let segments = $0.expression.as(StringLiteralExprSyntax.self)?.segments {
                if !["buildExpression", "buildBlock", "buildOptional", "buildEither", "buildArray", "buildFinalResult", "buildVirtualFor", "buildVirtualIf", "buildVirtualSwitch"].contains(segments.trimmedDescription) {
                    context.addDiagnostics(from: "'\(segments.trimmedDescription)' is not a valid build method", node: segments)
                }
                buildMethods.append(segments.trimmedDescription)
            } else {
                context.addDiagnostics(from: "'@ResultBuilder' requires static string literals", node: $0)
            }
        }
        
        guard let statements = declaration.body?.statements else {
            return []
        }
                
        var body: [CodeBlockItemSyntax] = []
        
        let component: DeclSyntax = "let _$component = { \(transformBlock(statements)) }()"
    
        body.append(component)
        
//        context.addDiagnostics(from: "\(component.leadingTrivia.debugDescription)", node: node)
        
        let finalResult: StmtSyntax = "return \(raw: builder).buildFinalResult(_$component)"
        body.append(finalResult)
                
        return body
        
        func transformFor(_ statement: ForStmtSyntax) -> [CodeBlockItemSyntax] {
            if buildMethods.contains("buildVirtualFor") {
                makeBuildVirtualFor(statement)
            } else {
                makeBuildArray(statement)
            }
        }
        
        func transformIf(_ expression: IfExprSyntax) -> [CodeBlockItemSyntax] {
            if buildMethods.contains("buildVirtualIf") {
                makeBuildVirtualIf(expression)
            } else {
                makeBuildOptionalOrEither(expression)
            }
        }
        
        func transformSwitch(_ expression: SwitchExprSyntax) -> [CodeBlockItemSyntax] {
            if buildMethods.contains("buildVirtualSwitch") {
                makeBuildVirtualSwitch(expression)
            } else {
                makeBuildEither(expression)
            }
        }
        
        func transformBlock(_ statements: CodeBlockItemListSyntax) -> [CodeBlockItemSyntax] {
            
            var body: [CodeBlockItemSyntax] = []
            
            var _components: [DeclSyntax] = []
            
            // let $component<INDEX> = <EXPR>
            func makeComponent(_ expr: ExprSyntax) -> DeclSyntax {
                "let _$component\(raw: _components.count): \(raw: builder).Component = \(expr)"
            }
            
            func flatBuildToComponent(_ statements: [CodeBlockItemSyntax]) {
                var statements = statements
                if let last = Syntax(statements.last?.item)?.as(VariableDeclSyntax.self)?.bindings.first {
                    if statements.count == 1, let value = last.initializer?.value {
                        let component = makeComponent(value)
                        _components.append(component)
                        body.append(component)
                    } else {
                        if let identifier = last.pattern.as(IdentifierPatternSyntax.self)?.identifier {
                            let _return: StmtSyntax = "return \(identifier)\n"
                            statements.append(_return)
                            let component = makeComponent("{\(statements)}()")
                            _components.append(component)
                            body.append(component)
                        }
                    }
                } else {
                    body.append(contentsOf: statements)
                }
            }
            
            for statement in statements {
                
                if let declaration = statement.item.as(VariableDeclSyntax.self) {
                    body.append("\(declaration, location: .filePath(context))")
                }
                
                if let expression = ExprSyntax(statement.item) {
                    let _expression = expression.trimmed(matching: \.isNewline)
                    let component = makeComponent("""
                    \(raw: builder).buildExpression(
                    \(_expression)
                    )
                    """)
                    _components.append(component)
                    body.append("\(component, location: context.location(of: expression, filePathMode: .filePath), lineOffset: -1)")
                }
                
                if let expression = statement.item.as(ExpressionStmtSyntax.self)?.expression.as(IfExprSyntax.self) {
                    let transformed = transformIf(expression)
                    flatBuildToComponent(transformed)
                }
                
                if let expression = statement.item.as(ExpressionStmtSyntax.self)?.expression.as(SwitchExprSyntax.self) {
                    let transformed = transformSwitch(expression)
                    flatBuildToComponent(transformed)
                }
                
                if let forStmt = statement.item.as(ForStmtSyntax.self) {
                    let transformed = transformFor(forStmt)
                    flatBuildToComponent(transformed)
                }
            }

            let components = _components.compactMap {
                $0.as(VariableDeclSyntax.self)?.bindings.first.map {
                    LabeledExprSyntax(expression: ExprSyntax("\($0.pattern)")).trimmed
                }
            }
            
            let buildBlock: StmtSyntax = "return \(raw: builder).buildBlock(\(components))"
            body.append(buildBlock)
            
            return body
            
        }
        
        // MARK: Default Build Methods
        
        func makeBuildArray(_ statement: ForStmtSyntax) -> [CodeBlockItemSyntax] {
            
            var items: [CodeBlockItemSyntax] = []
                    
            let _for: DeclSyntax = """
            let _ = {
            \(statement.with(\.body, "{ _ = \(statement.pattern.trimmed) }").trimmed(matching: \.isNewline))
            }
            """
            
            items.append("\(_for, location: context.location(of: statement, filePathMode: .filePath), lineOffset: -1)")
            
            let sequence: DeclSyntax = "\nlet $sequence = \(statement.sequence.trimmed)"
            
            items.append(sequence)

            let buildExpression: ExprSyntax = "\(raw: builder).buildExpression(\(statement.body.statements))"
            
            let components: DeclSyntax = """
            let $components = $sequence.map { \(statement.pattern.trimmed) in
            \(buildExpression, location: context.location(of: statement.body, at: .afterLeadingTrivia, filePathMode: .filePath))
            }
            """
            
            items.append(components)
            
            let binding: DeclSyntax = "let $component = \(raw: builder).buildArray($components)"
            items.append(binding)
            
            return items
        }
        
        func makeBuildOptionalOrEither(_ expression: IfExprSyntax) -> [CodeBlockItemSyntax] {
            
            var body: [CodeBlockItemSyntax] = []
            
            let call: DeclSyntax = "func call<T>(block: () -> T?) -> T? { block() }"
            body.append(call.formatted())
            
//            let bindings = BindingCollector(expression.conditions).matches.map(\.trimmedDescription)
            
            let bindings = LabeledExprListSyntax {
                BindingCollector(expression.conditions).matches.map {
                    LabeledExprSyntax(expression: ExprSyntax("\($0)")).trimmed
                }
            }
            
            let value: DeclSyntax = """
            let _value = call { 
                if \(expression.conditions.trimmed) { 
                    (\(bindings))
                } else {
                    nil
                }
            }
            """
            
            body.append(value)
            
            let then: DeclSyntax = """
            let $first = _value.map { (\(bindings)) in \(transformBlock(expression.body.statements)) }
            """
            body.append(then)
            
            guard let _second = Syntax(expression.elseBody)?.as(CodeBlockSyntax.self)?.statements else {
                let binding: DeclSyntax = "let $builder = \(raw: builder).buildOptional($first)"
                body.append(binding)
                return body
            }
            
            let secondExpr: DeclSyntax = "let $second = { \(transformBlock(_second)) }()"
            body.append(secondExpr.formatted())
            
            let binding: DeclSyntax = "let $builder = $first.map { \(raw: builder).buildEither(first: $0) } ?? \(raw: builder).buildEither(second: $second)"
            
            body.append(binding)
            
            return body
        }
        
        func makeBuildEither(_ expression: SwitchExprSyntax) -> [CodeBlockItemSyntax] {
            
            var body: [CodeBlockItemSyntax] = []
            
            let binding: DeclSyntax = "var _case: Int"
            body.append(binding)
            
            var _cases: SwitchCaseListSyntax = []
            
            var components: [DeclSyntax] = []
            
            var expressions: [DeclSyntax] = []
            
            var _expr = expression.trimmed(matching: \.isNewline, \.isComment)
                        
            for (index, _case) in expression.cases.enumerated() {
                
                switch _case {
                    case .switchCase(let original):
                        
                        let selection: ExprSyntax = "_case = \(raw: index)"
                        
                        let statements: CodeBlockItemListSyntax = [
                            CodeBlockItemSyntax(item: .init(selection))
                        ]
                        
                        _cases.append(.switchCase(SwitchCaseSyntax(label: original.label, statements: statements)))
                        
                        let name = "_expression\(index)"
                        
                        let expression: DeclSyntax = "let \(raw: name) = { \(transformBlock(original.statements))\n}()"
                        
                        expressions.append(expression)
                        
                        if index == 0 {
                            let component: DeclSyntax = "let _component\(raw: index) = \(raw: name)"
                            components.append(component)
                        } else {
                            let first = "\(builder).buildEither(first: \(name))"
                            let second = "\(builder).buildEither(second: _component\(index - 1))"
                            let component: DeclSyntax =  "let _component\(raw: index) = _case >= \(raw: index) ? \(raw: first) : \(raw: second)"
                            components.append(component)
                        }
                        
                    case .ifConfigDecl:
                        continue
                }
                
            }
            
            _expr.cases = _cases
                        
            body.append("\(_expr, location: context.location(of: expression, filePathMode: .filePath))")
            
            for expression in expressions {
                body.append(.init(item: .decl(expression.with(\.leadingTrivia, .newline))))
            }
            
            for builder in components {
                body.append(.init(item: .decl(builder.with(\.leadingTrivia, .newline))))
            }
            
            return body
            
        }
        
        // MARK: Virtual Build Methods
        
        func makeBuildVirtualFor(_ statement: ForStmtSyntax) -> [CodeBlockItemSyntax] {
            
            var items: [CodeBlockItemSyntax] = []
            
            let sequence: ExprSyntax = " { \(statement.sequence) }"
            
            let body: ExprSyntax = "{ \(statement.pattern.trimmed) in \(statement.body.statements.trimmed) }"
            
            let filter: ExprSyntax = if let condition = statement.whereClause?.condition {
                "{ \(statement.pattern.trimmed) in \(condition) }"
            } else {
                "{ _ in true }"
            }
            
            let component: DeclSyntax = "let $component = \(raw: builder).buildVirtualFor(\n\(sequence.trimmed), \(body), \(filter)\n)"
            items.append(component)
            
            return items
        }
        
        func makeBuildVirtualIf(_ expression: IfExprSyntax) -> [CodeBlockItemSyntax] {
            
            var body: [CodeBlockItemSyntax] = []
            
            let bindings = expression.conditions.compactMap {
                $0.condition.as(OptionalBindingConditionSyntax.self)?.pattern.trimmedDescription
            }
            
            let conditions: ExprSyntax = "{ if \(expression.conditions) { return (\(raw: bindings.joined(separator: ","))) } else { return nil } }"
            
            let thenBody: ExprSyntax = "{ (\(raw: bindings.joined(separator: ","))) in \(expression.body.statements.trimmed) }"
            
            let elseBody: ExprSyntax = Syntax(expression.elseBody)?.as(CodeBlockSyntax.self).map { "\($0)" } ?? "Optional<() -> Never>.none"
            
            let binding: DeclSyntax = "let $builder = \(raw: builder).buildVirtualIf(\(conditions), \(thenBody), \(elseBody))"
            
            body.append(binding)
            
            return body
        }
        
        func makeBuildVirtualSwitch(_ expression: SwitchExprSyntax) -> [CodeBlockItemSyntax] {
            
            let subject: ExprSyntax = "{ \(raw: expression.subject.trimmedDescription) }"
            
            var body: [CodeBlockItemSyntax] = []
            
            var pairs: [ExprSyntax] = []
            
            var _default: ExprSyntax?
            
            
            expression.cases.forEach {
                if let node = Syntax($0).as(SwitchCaseSyntax.self) {
                    if let label = node.label.as(SwitchCaseLabelSyntax.self) {
                        label.caseItems.forEach { item in
                            
                            let bindings = BindingCollector(item).matches.map(\.trimmedDescription)
                            
                            let pattern: ExprSyntax = "{ if case \(item) = $0 { return (\(raw: bindings.joined(separator: ","))) } else { return nil } }"
                            
                            let parameters = bindings.isEmpty ? "_" : "(\(bindings.joined(separator: ",")))"
                            let body: ExprSyntax = "{ \(raw: parameters) in \(node.statements.trimmed) }"
                            let pair: ExprSyntax = "(\(pattern), \(body))"
                            pairs.append(pair)
                            
                        }
                    }
                    if node.label.is(SwitchDefaultLabelSyntax.self) {
                        _default = "{ \(node.statements.trimmed) }"
                    }
                    
                }
            }
            
            _default = _default ?? "Optional<() -> Never>.none"
            
            let component: DeclSyntax = "let $switch = \(raw: builder).buildVirtualSwitch(\n\(subject), \(raw: pairs.map({ $0.with(\.leadingTrivia, .newline).description }).joined(separator: ","))\n, default: \(_default)\n)"
            
            body.append(component)
            
            return body
            
        }
        
    }
    
}

extension [CodeBlockItemSyntax] {
    mutating func append(_ node: some SyntaxProtocol) {
        if !node.leadingTrivia.contains(where: \.isNewline) {
            self.append(CodeBlockItemSyntax("\(node)").with(\.leadingTrivia, .newline))
        } else {
            self.append(CodeBlockItemSyntax("\(node)"))
        }
    }
}

extension SyntaxProtocol {
    public func trimmed(matching filter: ((TriviaPiece) -> Bool)...) -> Self {
        trimmed { piece in
            filter.reduce(false, { $0 || $1(piece) })
        }
    }
}

extension String: @retroactive Error { }

//extension Trivia {
//    
//    @_disfavoredOverload
//    func subtracting(_ piece: TriviaPiece) -> Trivia {
//        switch piece {
//            case .spaces(let diff):
//                if case .spaces(let count) = first(where: { $0.isSpaceOrTab }) {
//                    var pieces = self.pieces.filter({ !$0.isSpaceOrTab })
//                    pieces.append(.spaces(Swift.max(0, count - diff)))
//                    return Trivia(pieces: pieces)
//                }
//                return self
//            default:
//                return self
//        }
//    }
//    
//    func subtracting(_ trivia: Trivia) -> Trivia {
//        var copy = self
//        for piece in trivia.pieces {
//            copy = copy.subtracting(piece)
//        }
//        return copy
//    }
//    
//}
//
//extension SyntaxProtocol {
//    
//    func replacing(_ node: some SyntaxProtocol, using context: some MacroExpansionContext, offset: Int = 0) -> [CodeBlockItemSyntax] {
//        context.location(of: node)
//        if let location = context.location(of: node, at: .afterLeadingTrivia, filePathMode: .filePath) {
//            let line = Int(location.line.as(IntegerLiteralExprSyntax.self)?.literal.text ?? "0")! + offset
//            let block = CodeBlockItemListSyntax {
//                "\n#sourceLocation(file: \(location.file), line: \(raw: line))"
//                "\n\(self)"
//                "\n#sourceLocation()"
//            }
//            return block.map(\.self)
//        } else {
//            return []
//        }
//    }
//    
//}


// SwiftSyntaxBuilder

//extension CodeBlockItemListBuilder {
//    public static func buildFinalResult(_ component: Component) -> CodeBlockItemListSyntax {
//        .init(
//            component.enumerated().map { (index, expression) in
//                if index > component.startIndex, !expression.leadingTrivia.contains(where: \.isNewline) {
//                    expression.with(\.leadingTrivia, .newline.merging(expression.leadingTrivia))
//                } else {
//                    expression
//                }
//            }
//        )
//    }
//}
//
//extension SyntaxStringInterpolation {
//    
//    public mutating func appendInterpolation(_ statements: [CodeBlockItemSyntax]) {
//        appendInterpolation(CodeBlockItemListSyntax { statements })
//    }
//    public mutating func appendInterpolation(_ expressions: [LabeledExprSyntax]) {
//        appendInterpolation(LabeledExprListSyntax { expressions })
//    }
//    
//    public mutating func appendInterpolation<Node: SyntaxProtocol>(
//        _ node: Node,
//        location: AbstractSourceLocation?
//    ) {
//        if let location {
//            let block = CodeBlockItemListSyntax {
//                "#sourceLocation(file: \(location.file), line: \(location.line))"
//                "\(node)"
//                "#sourceLocation()"
//            }
//            appendInterpolation(block)
//        } else {
//            appendInterpolation(node)
//        }
//    }
//    
//    public mutating func appendInterpolation<Node: SyntaxProtocol>(
//        _ node: Node,
//        location: UnappliedContextLocation
//    ) {
//        appendInterpolation(node, location: location(of: node))
//    }
//    
//}
//
//public struct UnappliedContextLocation {
//    let context: any MacroExpansionContext
//    let filePathMode: SourceLocationFilePathMode
//    let position: PositionInSyntaxNode
//}
//
//extension UnappliedContextLocation {
//    
//    public static func filePath(_ context: some MacroExpansionContext, at position: PositionInSyntaxNode = .afterLeadingTrivia) -> UnappliedContextLocation {
//        .init(context: context, filePathMode: .filePath, position: position)
//    }
//    public static func fileID(_ context: some MacroExpansionContext, at position: PositionInSyntaxNode = .afterLeadingTrivia) -> UnappliedContextLocation {
//        .init(context: context, filePathMode: .fileID, position: position)
//    }
//    
//    func callAsFunction(of node: some SyntaxProtocol) -> AbstractSourceLocation? {
//        context.location(of: node, at: position, filePathMode: filePathMode)
//    }
//    
//}

extension MacroExpansionContext {
    func location(
        of node: some SyntaxProtocol,
        filePathMode: SourceLocationFilePathMode
    ) -> AbstractSourceLocation? {
        location(of: node, at: .afterLeadingTrivia, filePathMode: filePathMode)
    }
}

struct PartialAppliedLocation {
    let context: any MacroExpansionContext
    let filePathMode: SourceLocationFilePathMode
    let position: PositionInSyntaxNode
}

extension PartialAppliedLocation {
    static func filePath(_ context: some MacroExpansionContext, at position: PositionInSyntaxNode = .afterLeadingTrivia) -> PartialAppliedLocation {
        .init(context: context, filePathMode: .filePath, position: position)
    }
    
    func callAsFunction(of node: some SyntaxProtocol) -> AbstractSourceLocation? {
        context.location(of: node, at: position, filePathMode: filePathMode)
    }
}

extension SyntaxStringInterpolation {
    mutating func appendInterpolation<Node: SyntaxProtocol>(
        _ node: Node,
        location: AbstractSourceLocation?,
        lineOffset: Int? = nil
    ) {
        if let location {
          let line = if let lineOffset {
            ExprSyntax("\(literal: Int(location.line.as(IntegerLiteralExprSyntax.self)?.literal.text ?? "0")! + lineOffset)")
          } else {
            location.line
          }
            let block = CodeBlockItemListSyntax {
                "\n#sourceLocation(file: \(location.file), line: \(line))"
                "\(node)"
                "#sourceLocation()"
            }
            appendInterpolation(block)
        } else {
            appendInterpolation(node)
        }
    }
    
    mutating func appendInterpolation<Node: SyntaxProtocol>(
        _ node: Node,
        location: PartialAppliedLocation
    ) {
        appendInterpolation(node, location: location(of: node))
    }
}

extension SyntaxStringInterpolation {
  public mutating func appendInterpolation(_ statements: [CodeBlockItemSyntax]) {
    self.appendInterpolation(CodeBlockItemListSyntax { statements })
  }
  
  public mutating func appendInterpolation(_ expressions: [LabeledExprSyntax]) {
    self.appendInterpolation(LabeledExprListSyntax { expressions })
  }
}
