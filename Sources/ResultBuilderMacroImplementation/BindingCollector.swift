//
//  Untitled.swift
//  ResultBuilderMacro
//
//  Created by Mateus Rodrigues on 02/08/24.
//

import SwiftSyntax

class BindingCollector: SyntaxVisitor {
    
    private(set) var matches: [PatternSyntax] = []
    
    init(_ node: some SyntaxProtocol) {
        super.init(viewMode: .all)
        self.walk(node)
    }
    
    override func visit(_ node: ValueBindingPatternSyntax) -> SyntaxVisitorContinueKind {
        matches.append(node.pattern)
        return .visitChildren
    }
    
    override func visit(_ node: OptionalBindingConditionSyntax) -> SyntaxVisitorContinueKind {
        matches.append(node.pattern)
        return .visitChildren
    }
    
}
