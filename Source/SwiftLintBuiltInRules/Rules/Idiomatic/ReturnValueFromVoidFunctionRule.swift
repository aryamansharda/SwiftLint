import SwiftSyntax

struct ReturnValueFromVoidFunctionRule: OptInRule, SwiftSyntaxRule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "return_value_from_void_function",
        name: "Return Value from Void Function",
        description: "Returning values from Void functions should be avoided",
        kind: .idiomatic,
        minSwiftVersion: .fiveDotOne,
        nonTriggeringExamples: ReturnValueFromVoidFunctionRuleExamples.nonTriggeringExamples,
        triggeringExamples: ReturnValueFromVoidFunctionRuleExamples.triggeringExamples
    )

    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor {
        Visitor(viewMode: .sourceAccurate)
    }
}

private extension ReturnValueFromVoidFunctionRule {
    final class Visitor: ViolationsSyntaxVisitor {
        override func visitPost(_ node: ReturnStmtSyntax) {
            if node.expression != nil,
               let functionNode = Syntax(node).enclosingFunction(),
               functionNode.returnsVoid {
                violations.append(node.positionAfterSkippingLeadingTrivia)
            }
        }
    }
}

private extension Syntax {
    func enclosingFunction() -> FunctionDeclSyntax? {
        if let node = self.as(FunctionDeclSyntax.self) {
            return node
        }

        if self.is(ClosureExprSyntax.self) || self.is(VariableDeclSyntax.self) {
            return nil
        }

        return parent?.enclosingFunction()
    }
}

private extension FunctionDeclSyntax {
    var returnsVoid: Bool {
        if let type = signature.returnClause?.type.as(IdentifierTypeSyntax.self) {
            return type.name.text == "Void"
        }

        return signature.returnClause?.type == nil
    }
}
