//
//  File.swift
//  ResultBuilderMacro
//
//  Created by Mateus Rodrigues on 01/08/24.
//

import ResultBuilderMacro


extension String: ResultBuilder {
    
    public static func buildBlock(_ components: String...) -> String {
        print(#function)
        return components.filter({ !$0.isEmpty }).joined(separator: ",")
    }
    
//    public static func buildExpression(_ expression: Int) -> String {
//        print(#function)
//        return "\(expression)"
//    }
    
    public static func buildOptional(_ component: String?) -> String {
        print(#function)
        return component ?? ""
    }
    
    public static func buildEither(first component: String) -> String {
        print(#function)
        return component
    }
    
    public static func buildEither(second component: String) -> String {
        print(#function)
        return component
    }
    
    public static func buildArray(_ components: [String]) -> String {
        print(#function)
        return components.joined(separator: ",")
    }
    
    static func buildVirtualSwitch<Subject, each ConditionReturn, each CaseReturn, DefaultReturn>(
        _ subject: () -> Subject,
        _ cases: repeat (condition: (Subject) -> (each ConditionReturn)?, body: (each ConditionReturn) -> (each CaseReturn)),
        default: (() -> DefaultReturn)?
    ) -> String {
        print(#function)
        let subject = subject()
        for (item, body) in repeat (each cases) {
            if let item = item(subject) {
                return "\(body(item))"
            }
        }
        if let `default` {
            return "\(`default`())"
        }
        return ""
    }
    
    static func buildVirtualIf<ConditionsReturn, ThenReturn, ElseReturn>(
        _ conditions: () -> ConditionsReturn?,
        _ then: (ConditionsReturn) -> ThenReturn,
        _ else: (() -> ElseReturn)?
    ) -> String {
        print(#function)
        if let conditions = conditions() {
            return "\(then(conditions))"
        } else {
            if let `else` {
                return "\(`else`())"
            }
            return ""
        }
    }
    
    static func buildVirtualFor<S: Sequence, BodyReturn>(
        _ sequence: () -> (S),
        _ body: (S.Element) -> BodyReturn,
        _ isIncluded: (S.Element) -> Bool
    ) -> String {
        print(#function)
        return sequence().filter(isIncluded).map({ "\($0)" }).joined(separator: ",")
    }
    
    public static func buildFinalResult(_ component: String) -> String {
        return "RESULT = \(component)"
    }
    
}
