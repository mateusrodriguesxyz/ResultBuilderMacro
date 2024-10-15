import SwiftSyntax
@_spi(ExperimentalLanguageFeature) import SwiftSyntaxMacros

@_spi(ExperimentalLanguageFeature)
public struct ResultBuilderMacro: BodyMacro {
    
    public static func expansion(of node: AttributeSyntax, providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax, in context: some MacroExpansionContext) throws -> [CodeBlockItemSyntax] {
        
        guard let builder = node.attributeName.as(IdentifierTypeSyntax.self)?.genericArgumentClause?.arguments.first?.trimmedDescription else {
            return []
        }
        
        if let statements = declaration.body?.statements {
            var body: [CodeBlockItemSyntax] = []
            let component: DeclSyntax = "let $component = { \(transformBlock(statements)) }()"
            body.append(component)
            let finalResult: ExprSyntax = "return \(raw: builder).buildFinalResult($component)"
            body.append(finalResult)
            return body
        } else {
            return []
        }
        
        func transformIfExpr(_ expression: IfExprSyntax) -> [CodeBlockItemSyntax] {
            
            var body: [CodeBlockItemSyntax] = []
                        
            let condition = expression.conditions.trimmedDescription
            
            let _first = expression.body.statements
            
            guard let _second = Syntax(expression.elseBody)?.as(CodeBlockSyntax.self)?.statements else {
                let component: DeclSyntax = "let $component = { \(transformBlock(_first)) }()"
                body.append(component)
                let binding: DeclSyntax = "let $builder = \(raw: builder).buildOptional($component)"
                body.append(binding)
                return body
            }
            let firstExpr: DeclSyntax = "let $first = { \(transformBlock(_first)) }()"
            let secondExpr: DeclSyntax = "let $second = { \(transformBlock(_second)) }()"
            
            body.append(firstExpr)
            body.append(secondExpr)
            
            let first = "\(builder).buildEither(first: $first)"
            let second = "\(builder).buildEither(second: $second)"
            
            let binding: DeclSyntax = "let $builder = \(raw: condition) ? \(raw: first) : \(raw: second)"
           
            body.append(binding)
            
            return body
        }
        
        func transformSwitchExpr(_ expression: SwitchExprSyntax) -> [CodeBlockItemSyntax] {
            
            var body: [CodeBlockItemSyntax] = []
            
            let binding: DeclSyntax = "var $case: Int"
            
            body.append(binding)
            
            var _cases: SwitchCaseListSyntax = []
            
            var components: [DeclSyntax] = []
            
            var expressions: [DeclSyntax] = []
            
            for (index, _case) in expression.cases.enumerated() {
                
                switch _case {
                case .switchCase(let original):
                    
                    let selection: ExprSyntax = "$case = \(raw: index)"
                    
                    let statements: CodeBlockItemListSyntax = [
                        CodeBlockItemSyntax(item: .init(selection))
                    ]
                    
                    _cases.append(.switchCase(SwitchCaseSyntax(label: original.label, statements: statements)))
                    
                    let name = "$expression\(index)"
                                        
                    let expression: DeclSyntax = "let \(raw: name) = { \(transformBlock(original.statements)) }()"
                    
                    expressions.append(expression)
                    
                    if index == 0 {
                        let component: DeclSyntax = "let $component\(raw: index) = \(raw: name)"
                        components.append(component)
                    } else {
                        let first = "\(builder).buildEither(first: \(name))"
                        let second = "\(builder).buildEither(second: $component\(index - 1))"
                        let component: DeclSyntax =  "let $component\(raw: index) = $case >= \(raw: index) ? \(raw: first) : \(raw: second)"
                        components.append(component)
                    }
                    
                case .ifConfigDecl:
                    continue
                }
                
            }
            
            let _expr = SwitchExprSyntax(subject: expression.subject.with(\.leadingTrivia, .space), cases: _cases)
            
            body.append(_expr.with(\.leadingTrivia, .newline))
            body.append(_expr.with(\.leadingTrivia, .newline))

            
            for expression in expressions {
                body.append(expression.with(\.leadingTrivia, .newline))
            }
            
            for builder in components {
                body.append(builder.with(\.leadingTrivia, .newline))
            }
            
            return body
            
        }
        
        func transformForStmt(_ statement: ForStmtSyntax) -> [CodeBlockItemSyntax] {

            var items: [CodeBlockItemSyntax] = []
            
            let sequence: DeclSyntax = "let $sequence = \(statement.sequence.trimmed)"
            items.append(sequence)

            let body: ExprSyntax = "{ \(statement.pattern.trimmed) in \(statement.body.statements.trimmed) }"
            
            let components: DeclSyntax = "let $components = $sequence.map \(body.trimmed)"
            items.append(components)

            let binding: DeclSyntax = "let $component = \(raw: builder).buildArray($components)"
            items.append(binding)
            
            return items
        }
        
        func transformBlock(_ statements: CodeBlockItemListSyntax) -> [CodeBlockItemSyntax] {
            
            var body: [CodeBlockItemSyntax] = []
            var bindingRefs: [DeclReferenceExprSyntax] = []
            
            func makeBuilderExpression(_ statements: [CodeBlockItemSyntax], index: Int) {
                var statements = statements
                if let last = Syntax(statements.last?.item)?.as(VariableDeclSyntax.self) {
                    if let identifier = last.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier {
                        statements.append(.init(item: .stmt("return \(identifier)")))
                        let component: DeclSyntax = "let $component\(raw: index) = { \(CodeBlockItemListSyntax { statements }) }()"
                        bindingRefs.append(DeclReferenceExprSyntax(baseName: "$component\(raw: index)"))
                        body.append(component)
                    }
                }
            }
            
            for (index, statement) in statements.enumerated() {
                
                if let declaration = statement.item.as(VariableDeclSyntax.self) {
                    body.append(declaration)
                }
                
                if let expression = ExprSyntax(statement.item) {
                    let identifer = "$component\(index)"
                    let component: DeclSyntax = "let \(raw: identifer) = \(raw: builder).buildExpression(\(expression.trimmed))"
                    bindingRefs.append(DeclReferenceExprSyntax(baseName: .identifier(identifer)))
                    body.append(component)
                }
                
                if let ifExpr = statement.item.as(ExpressionStmtSyntax.self)?.expression.as(IfExprSyntax.self) {
                    let transformed = transformIfExpr(ifExpr)
                    makeBuilderExpression(transformed, index: index)
                }
                
                if let switchExpr = statement.item.as(ExpressionStmtSyntax.self)?.expression.as(SwitchExprSyntax.self) {
                    let transformed = transformSwitchExpr(switchExpr)
                    makeBuilderExpression(transformed, index: index)
                }
                
                if let forStmt = statement.item.as(ForStmtSyntax.self) {
                    let transformed = transformForStmt(forStmt)
                    makeBuilderExpression(transformed, index: index)
                }
            }
            
            let components = LabeledExprListSyntax {
                bindingRefs.map {
                    LabeledExprSyntax(expression: $0)
                }
            }
            
            let buildBlock: StmtSyntax = "return \(raw: builder).buildBlock(\(raw: components))"
            
            body.append(buildBlock)
            
            return body
            
        }
        
    }
    
}
