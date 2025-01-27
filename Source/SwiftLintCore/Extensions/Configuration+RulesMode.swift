public extension Configuration {
    /// Returns the rule for the specified ID, if configured in this configuration.
    ///
    /// - parameter ruleID: The identifier for the rule to look up.
    ///
    /// - returns: The rule for the specified ID, if configured in this configuration.
    func configuredRule(forID ruleID: String) -> (any Rule)? {
        rules.first { rule in
            if type(of: rule).description.identifier == ruleID {
                if let customRules = rule as? CustomRules {
                    return customRules.configuration.customRuleConfigurations.isNotEmpty
                }
                return true
            }
            return false
        }
    }

    /// Represents how a Configuration object can be configured with regards to rules.
    enum RulesMode: Equatable {
        /// The default rules mode, which will enable all rules that aren't defined as being opt-in
        /// (conforming to the `OptInRule` protocol), minus the rules listed in `disabled`, plus the rules listed in
        /// `optIn`.
        case `default`(disabled: Set<String>, optIn: Set<String>)

        /// Only enable the rules explicitly listed.
        case only(Set<String>)

        /// Enable all available rules.
        case allEnabled

        internal init(
            enableAllRules: Bool,
            onlyRules: [String],
            optInRules: [String],
            disabledRules: [String],
            analyzerRules: [String]
        ) throws {
            func warnAboutDuplicates(in identifiers: [String]) {
                if Set(identifiers).count != identifiers.count {
                    let duplicateRules = identifiers.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
                        .filter { $0.1 > 1 }
                    for duplicateRule in duplicateRules {
                        Issue.listedMultipleTime(ruleID: duplicateRule.0, times: duplicateRule.1).print()
                    }
                }
            }

            if enableAllRules {
                self = .allEnabled
            } else if onlyRules.isNotEmpty {
                if disabledRules.isNotEmpty || optInRules.isNotEmpty {
                    throw Issue.genericWarning(
                        "'\(Configuration.Key.disabledRules.rawValue)' or " +
                            "'\(Configuration.Key.optInRules.rawValue)' cannot be used in combination " +
                        "with '\(Configuration.Key.onlyRules.rawValue)'"
                    )
                }

                warnAboutDuplicates(in: onlyRules + analyzerRules)
                self = .only(Set(onlyRules + analyzerRules))
            } else {
                warnAboutDuplicates(in: disabledRules)

                let effectiveOptInRules: [String]
                if optInRules.contains(RuleIdentifier.all.stringRepresentation) {
                    let allOptInRules = RuleRegistry.shared.list.list.compactMap { ruleID, ruleType in
                        ruleType is any OptInRule.Type && !(ruleType is any AnalyzerRule.Type) ? ruleID : nil
                    }
                    effectiveOptInRules = Array(Set(allOptInRules + optInRules))
                } else {
                    effectiveOptInRules = optInRules
                }

                let effectiveAnalyzerRules: [String]
                if analyzerRules.contains(RuleIdentifier.all.stringRepresentation) {
                    let allAnalyzerRules = RuleRegistry.shared.list.list.compactMap { ruleID, ruleType in
                        ruleType is any AnalyzerRule.Type ? ruleID : nil
                    }
                    effectiveAnalyzerRules = allAnalyzerRules
                } else {
                    effectiveAnalyzerRules = analyzerRules
                }

                warnAboutDuplicates(in: effectiveOptInRules + effectiveAnalyzerRules)
                self = .default(disabled: Set(disabledRules), optIn: Set(effectiveOptInRules + effectiveAnalyzerRules))
            }
        }

        internal func applied(aliasResolver: (String) -> String) -> Self {
            switch self {
            case let .default(disabled, optIn):
                return .default(
                    disabled: Set(disabled.map(aliasResolver)),
                    optIn: Set(optIn.map(aliasResolver))
                )

            case let .only(onlyRules):
                return .only(Set(onlyRules.map(aliasResolver)))

            case .allEnabled:
                return .allEnabled
            }
        }

        internal func activateCustomRuleIdentifiers(allRulesWrapped: [ConfigurationRuleWrapper]) -> Self {
            // In the only mode, if the custom rules rule is enabled, all custom rules are also enabled implicitly
            // This method makes the implicitly explicit
            switch self {
            case let .only(onlyRules) where onlyRules.contains { $0 == CustomRules.description.identifier }:
                let customRulesRule = (allRulesWrapped.first { $0.rule is CustomRules })?.rule as? CustomRules
                let customRuleIdentifiers = customRulesRule?.configuration.customRuleConfigurations.map(\.identifier)
                return .only(onlyRules.union(Set(customRuleIdentifiers ?? [])))

            default:
                return self
            }
        }
    }
}
