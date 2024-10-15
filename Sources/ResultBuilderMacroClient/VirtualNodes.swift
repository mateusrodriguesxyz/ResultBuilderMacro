//
//  VirtualNodes.swift
//  
//
//  Created by Mateus Rodrigues on 08/07/24.
//

struct VirtualForStmt<T: Sequence, BodyReturn> {
    let sequence: T
    let body: (T.Element) -> BodyReturn
    let whereClause: (T.Element) -> Bool
}

struct VirtualIfExpr<ConditionsReturn, BodyReturn, ElseBodyReturn> {
    let conditions: () -> ConditionsReturn?
    let thenBody: (ConditionsReturn) -> BodyReturn
    let elseBody: () -> ElseBodyReturn
}

func buildVirtualFor<S: Sequence, BodyReturn>(sequence: S, body: (S.Element) -> BodyReturn, whereClause: (S.Element) -> Bool) {
    
}

func buildVirtualIf<each ConditionsReturn, each ThenReturn>(_ bodies: repeat (() -> (each ConditionsReturn)?, (each ConditionsReturn) -> (each ThenReturn))) {
    for (conditions, body) in repeat (each bodies) {
        if let conditions = conditions() {
            let _ = body(conditions)
            break
        }
    }
}

func buildVirtualIf<ConditionsReturn, ThenReturn, ElseReturn>(conditions: () -> ConditionsReturn?, thenBody: (ConditionsReturn) -> ThenReturn, elseBody: () -> ElseReturn) {
    
}

func buildVirtualSwitch<Subject, each ItemReturn, each CaseReturn>(_ subject: () -> Subject, _ cases: repeat ((Subject) -> (each ItemReturn)?, (each ItemReturn) -> (each CaseReturn))) {
    var count = 0
    for _ in repeat (each cases) {
        count += 1
    }
    print("cases: \(count)")
    for (item, body) in repeat (each cases) {
        if let item = item(subject()) {
            let _ = body(item)
            break
        }
    }
}

func buildIf() {
        
    let a: Int? = nil
    let b: Int? = nil
    
    let _if = VirtualIfExpr {
        if let a, let b {
            return (a, b)
        } else {
            return nil
        }
    } thenBody: { (a, b) in
        "\(a) \(b)"
    } elseBody: {
        1.5
    }
    
}
