import Foundation

/// Holds user-specified category overrides for transactions within a single app session.
///
/// Overrides reset on every fresh launch because `sampleTransactions()` generates new
/// `UUID`s each time.  For a demo prototype that runs as one continuous session this is
/// the desired behaviour — every relaunch starts from a clean slate.
@Observable
final class TransactionStore {

    /// Maps a transaction's UUID to the raw value of the user-chosen `ExpenseCategory`.
    var categoryOverrides: [UUID: String] = [:]

    // MARK: - Mutation

    func setCategory(_ category: ExpenseCategory, for id: UUID) {
        categoryOverrides[id] = category.rawValue
    }

    // MARK: - Queries

    /// The effective category raw value for a transaction, applying any stored override.
    func resolvedCategory(for tx: Transaction) -> String? {
        categoryOverrides[tx.id] ?? tx.expenseCategory
    }

    /// True when the transaction's effective category excludes it from P&L charts
    /// and totals (i.e. it has been assigned to Personal or Transfers).
    func isExcludedFromPL(_ tx: Transaction) -> Bool {
        let raw = categoryOverrides[tx.id] ?? tx.expenseCategory ?? ""
        return ExpenseCategory(rawValue: raw)?.excludedFromPL ?? false
    }
}
