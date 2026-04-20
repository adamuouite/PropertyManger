import SwiftUI
import SwiftData
import Charts

// MARK: - Main View

struct RentsView: View {
    @Query(sort: \RentPayment.year, order: .reverse) private var allPayments: [RentPayment]
    @Query(sort: \Contract.contractNumber) private var contracts: [Contract]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.loc) var loc
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedContract: Contract? = nil
    @State private var statusFilter: PaymentStatus? = nil
    @State private var showAddPayment = false
    @State private var showExport = false
    @State private var editPayment: RentPayment?
    @State private var deleteTarget: RentPayment?
    @State private var isSelectMode = false
    @State private var multiSelection = Set<PersistentIdentifier>()
    @State private var showBulkDeleteConfirm = false

    var canEdit: Bool { authManager.canPerform(.managePayments) }

    var filteredPayments: [RentPayment] {
        allPayments.filter { p in
            let matchContract = selectedContract == nil || p.contract?.persistentModelID == selectedContract?.persistentModelID
            let matchStatus = statusFilter == nil || p.status == statusFilter
            return matchContract && matchStatus
        }
        .sorted { ($0.year, $0.month) > ($1.year, $1.month) }
    }

    var chartData: [(label: String, paid: Double, pending: Double, overdue: Double)] {
        let grouped = Dictionary(grouping: allPayments) { "\($0.year)-\(String(format: "%02d", $0.month))" }
        return grouped.sorted { $0.key < $1.key }.suffix(6).map { _, items in
            let month = items[0].month
            let year = items[0].year
            let paid = items.filter { $0.status == .paid }.reduce(0) { $0 + ($1.isExpense ? -$1.paidAmount : $1.paidAmount) }
            let pending = items.filter { $0.status == .pending }.reduce(0) { $0 + ($1.isExpense ? -$1.amount : $1.amount) }
            let overdue = items.filter { $0.status == .overdue }.reduce(0) { $0 + ($1.isExpense ? -$1.amount : $1.amount) }
            return (label: "\(month)/\(year)", paid: paid, pending: pending, overdue: overdue)
        }
    }

    var summary: (paid: Int, pending: Int, overdue: Int, partial: Int) {
        (
            paid: filteredPayments.filter { $0.status == .paid }.count,
            pending: filteredPayments.filter { $0.status == .pending }.count,
            overdue: filteredPayments.filter { $0.status == .overdue }.count,
            partial: filteredPayments.filter { $0.status == .partial }.count
        )
    }

    var body: some View {
        HSplitView {
            // MARK: Left – Chart + filters
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary chips
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        PaymentSummaryChip(count: summary.paid, label: loc.t("rent.status.paid"), color: .green, icon: "checkmark.circle.fill")
                        PaymentSummaryChip(count: summary.pending, label: loc.t("rent.status.pending"), color: .orange, icon: "clock.fill")
                        PaymentSummaryChip(count: summary.overdue, label: loc.t("rent.status.overdue"), color: .red, icon: "exclamationmark.triangle.fill")
                        PaymentSummaryChip(count: summary.partial, label: loc.t("rent.status.partial"), color: .yellow, icon: "minus.circle.fill")
                    }

                    // Chart
                    VStack(alignment: .leading, spacing: 8) {
                        Label(loc.t("rent.monthly_overview"), systemImage: "chart.bar.fill")
                            .font(.headline)

                        if chartData.isEmpty {
                            ContentUnavailableView(loc.t("rent.no_data"), systemImage: "eurosign.circle")
                                .frame(height: 150)
                        } else {
                            Chart {
                                ForEach(chartData, id: \.label) { d in
                                    BarMark(x: .value("Month", d.label), y: .value("Paid", d.paid))
                                        .foregroundStyle(Color.green.gradient)
                                    BarMark(x: .value("Month", d.label), y: .value("Pending", d.pending))
                                        .foregroundStyle(Color.orange.opacity(0.6).gradient)
                                    BarMark(x: .value("Month", d.label), y: .value("Overdue", d.overdue))
                                        .foregroundStyle(Color.red.opacity(0.6).gradient)
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic) { _ in
                                    AxisValueLabel().font(.caption2)
                                }
                            }
                            .frame(height: 160)
                        }
                    }
                    .padding()
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Filters
                    VStack(alignment: .leading, spacing: 8) {
                        Text(loc.t("rent.filter_contract")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Picker("Contract", selection: $selectedContract) {
                            Text(loc.t("rent.all_contracts")).tag(Optional<Contract>.none)
                            ForEach(contracts, id: \.persistentModelID) { c in
                                let label = c.apartment.map { c.contractNumber + " – " + $0.displayName } ?? c.contractNumber
                                Text(label).tag(Optional(c))
                            }
                        }
                        .pickerStyle(.menu)

                        Text(loc.t("rent.filter_status")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                FilterChip(label: loc.t("common.all"), selected: statusFilter == nil) { statusFilter = nil }
                                ForEach(PaymentStatus.allCases, id: \.self) { s in
                                    FilterChip(label: s.rawValue, selected: statusFilter == s) { statusFilter = s }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .frame(minWidth: 280, maxWidth: 320)

            // MARK: Right – Payment List
            VStack(spacing: 0) {
                HStack {
                    Text("\(loc.t("rent.payments")) (\(filteredPayments.count))")
                        .font(.headline)
                    Spacer()
                    if canEdit {
                        if isSelectMode {
                            Button {
                                if multiSelection.count == filteredPayments.count {
                                    multiSelection.removeAll()
                                } else {
                                    multiSelection = Set(filteredPayments.map(\.persistentModelID))
                                }
                            } label: {
                                Text(multiSelection.count == filteredPayments.count ? loc.t("common.deselect_all") : loc.t("common.select_all"))
                            }.buttonStyle(.bordered).font(.caption)

                            if !multiSelection.isEmpty {
                                Button(role: .destructive) { showBulkDeleteConfirm = true } label: {
                                    Label("\(loc.t("common.delete")) (\(multiSelection.count))", systemImage: "trash.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderedProminent).tint(.red)
                            }
                            Button(loc.t("common.done")) { isSelectMode = false; multiSelection.removeAll() }
                                .buttonStyle(.bordered).font(.caption)
                        } else {
                            Button { isSelectMode = true } label: {
                                Label(loc.t("rent.select_mode"), systemImage: "checkmark.circle")
                            }.buttonStyle(.bordered)
                            Button { showAddPayment = true } label: {
                                Label(loc.t("rent.add"), systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(contracts.isEmpty)
                        }
                    }
                }
                .padding(16)

                Divider()

                if filteredPayments.isEmpty {
                    ContentUnavailableView(
                        loc.t("rent.no_payments"),
                        systemImage: "eurosign.circle",
                        description: Text(loc.t("rent.no_payments_desc"))
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredPayments) { payment in
                            HStack(spacing: 8) {
                                if isSelectMode {
                                    Image(systemName: multiSelection.contains(payment.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(multiSelection.contains(payment.persistentModelID) ? Color.accentColor : .secondary)
                                        .onTapGesture {
                                            if multiSelection.contains(payment.persistentModelID) {
                                                multiSelection.remove(payment.persistentModelID)
                                            } else {
                                                multiSelection.insert(payment.persistentModelID)
                                            }
                                        }
                                }
                                PaymentRow(payment: payment, canEdit: canEdit, onEdit: { editPayment = payment })
                            }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if canEdit {
                                        Button(role: .destructive) {
                                            deleteTarget = payment
                                        } label: {
                                            Label(loc.t("common.delete"), systemImage: "trash")
                                        }
                                        Button {
                                            markAsPaid(payment)
                                        } label: {
                                            Label(loc.t("rent.mark_paid"), systemImage: "checkmark")
                                        }
                                        .tint(.green)
                                        .disabled(payment.status == .paid)
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle(loc.t("rent.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showExport = true } label: {
                    Label(loc.t("export.title"), systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showExport) { ExportReportView() }
        .sheet(isPresented: $showAddPayment) {
            AddEditPaymentView(payment: nil, contracts: contracts)
        }
        .sheet(item: $editPayment) { p in
            AddEditPaymentView(payment: p, contracts: contracts)
        }
        .confirmationDialog(loc.t("rent.delete_confirm"),
                            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible) {
            Button(loc.t("common.delete"), role: .destructive) {
                if let p = deleteTarget {
                    modelContext.delete(p)
                    try? modelContext.save()
                    deleteTarget = nil
                }
            }
        } message: { Text(loc.t("rent.delete_msg")) }
        .confirmationDialog(String(format: loc.t("rent.bulk_delete"), multiSelection.count),
            isPresented: $showBulkDeleteConfirm, titleVisibility: .visible) {
            Button(loc.t("common.delete"), role: .destructive) {
                for payment in allPayments where multiSelection.contains(payment.persistentModelID) {
                    modelContext.delete(payment)
                }
                try? modelContext.save()
                multiSelection.removeAll(); isSelectMode = false
            }
        } message: { Text(loc.t("rent.bulk_delete_msg")) }
    }

    private func markAsPaid(_ payment: RentPayment) {
        payment.status = .paid
        payment.paidAmount = payment.amount
        payment.paidDate = Date()
        try? modelContext.save()
    }
}

// MARK: - Payment Row

struct PaymentRow: View {
    let payment: RentPayment
    let canEdit: Bool
    let onEdit: () -> Void
    @Environment(\.loc) var loc

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: payment.status.icon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(payment.monthName).font(.headline)
                    if payment.isExpense {
                        Text(loc.t("rent.expense"))
                            .font(.caption2.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.red).clipShape(Capsule())
                    }
                    Spacer()
                    Text((payment.isExpense ? "−" : "") + payment.amount.formatted(.currency(code: "EUR")))
                        .font(.headline.bold())
                        .foregroundStyle(payment.isExpense ? .red : .primary)
                }
                HStack(spacing: 6) {
                    if let company = payment.contract?.apartment?.company {
                        Text(company.rawValue)
                            .font(.caption2.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(companyColor(company)).clipShape(Capsule())
                    }
                    if let tenant = payment.contract?.tenant, !tenant.tenantNumber.isEmpty {
                        Text(tenant.tenantNumber)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.indigo).clipShape(Capsule())
                    }
                    if let contractNum = payment.contract?.contractNumber {
                        Text(contractNum).font(.caption).foregroundStyle(.secondary)
                        Text("·").foregroundStyle(.secondary)
                    }
                    Text("\(loc.t("rent.due_date")): \(DateFormatter.display.string(from: payment.dueDate))")
                        .font(.caption).foregroundStyle(.secondary)
                    if let paidDate = payment.paidDate {
                        Text("· \(loc.t("rent.status.paid")): \(DateFormatter.display.string(from: paidDate))")
                            .font(.caption).foregroundStyle(.green)
                    }
                }
                if payment.status == .partial {
                    Text("\(loc.t("rent.status.paid")): \(payment.paidAmount.formatted(.currency(code: "EUR"))) / \(payment.amount.formatted(.currency(code: "EUR")))")
                        .font(.caption2).foregroundStyle(.orange)
                }
            }

            StatusBadge(text: payment.status.rawValue, icon: payment.status.icon)

            if canEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    var statusColor: Color {
        switch payment.status {
        case .paid: return .green
        case .pending: return .orange
        case .overdue: return .red
        case .partial: return .yellow
        }
    }
}

// MARK: - Add/Edit Payment

struct AddEditPaymentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) var loc

    let payment: RentPayment?
    let contracts: [Contract]

    @State private var selectedContract: Contract?
    @State private var amount = 0.0
    @State private var paidAmount = 0.0
    @State private var dueDate = Date()
    @State private var paidDate: Date? = nil
    @State private var month = Calendar.current.component(.month, from: Date())
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var status: PaymentStatus = .pending
    @State private var notes = ""
    @State private var hasPaidDate = false
    @State private var isExpense = false
    private let minDate = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1))!

    var isEditing: Bool { payment != nil }
    var isValid: Bool { amount > 0 && selectedContract != nil }

    let months = ["January","February","March","April","May","June",
                  "July","August","September","October","November","December"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? loc.t("rent.edit") : loc.t("rent.add")).font(.title2.bold())
                Spacer()
                Button(loc.t("common.cancel")) { dismiss() }.keyboardShortcut(.escape)
                Button(isEditing ? loc.t("common.save") : loc.t("rent.record")) { save() }
                    .buttonStyle(.borderedProminent).disabled(!isValid)
            }
            .padding(20)
            Divider()

            Form {
                Section(loc.t("rent.contract_section")) {
                    Picker(loc.t("rent.contract_section") + " *", selection: $selectedContract) {
                        Text(loc.t("rent.select_contract")).tag(Optional<Contract>.none)
                        ForEach(contracts, id: \.persistentModelID) { c in
                            let aptName = c.apartment?.displayName ?? "No apartment"
                            Text(c.contractNumber + " – " + aptName).tag(Optional(c))
                        }
                    }
                    .onChange(of: selectedContract) { _, c in
                        if let c { amount = c.rentAmount }
                    }
                }

                Section(loc.t("rent.period")) {
                    Picker(loc.t("rent.month"), selection: $month) {
                        ForEach(1...12, id: \.self) { m in Text(months[m-1]).tag(m) }
                    }
                    Picker(loc.t("rent.year"), selection: $year) {
                        ForEach((2020...2035), id: \.self) { y in Text(String(y)).tag(y) }
                    }
                    DatePicker(loc.t("rent.due_date"), selection: $dueDate, in: minDate..., displayedComponents: .date)
                }

                Section(loc.t("rent.payment_section")) {
                    Picker(loc.t("rent.direction"), selection: $isExpense) {
                        Label(loc.t("rent.income"), systemImage: "arrow.down.circle.fill").tag(false)
                        Label(loc.t("rent.expense"), systemImage: "arrow.up.circle.fill").tag(true)
                    }

                    HStack {
                        Text(loc.t("rent.amount") + " *")
                        Spacer()
                        TextField("0", value: $amount, format: .number)
                            .frame(width: 100).multilineTextAlignment(.trailing)
                    }

                    Picker(loc.t("rent.status"), selection: $status) {
                        ForEach(PaymentStatus.allCases, id: \.self) { s in
                            Label(s.rawValue, systemImage: s.icon).tag(s)
                        }
                    }
                    .onChange(of: status) { _, newStatus in
                        if newStatus == .paid {
                            paidAmount = amount
                            hasPaidDate = true
                            if paidDate == nil { paidDate = Date() }
                        }
                    }

                    if status == .partial {
                        HStack {
                            Text(loc.t("rent.amount_paid"))
                            Spacer()
                            TextField("0", value: $paidAmount, format: .number)
                                .frame(width: 100).multilineTextAlignment(.trailing)
                        }
                    }

                    Toggle(loc.t("rent.record_paid_date"), isOn: $hasPaidDate)
                    if hasPaidDate {
                        DatePicker(loc.t("rent.paid_on"), selection: Binding(
                            get: { paidDate ?? Date() },
                            set: { paidDate = $0 }
                        ), in: minDate..., displayedComponents: .date)
                    }
                }

                Section(loc.t("common.notes")) {
                    TextEditor(text: $notes).frame(minHeight: 50)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: 520)
        .onAppear {
            if let p = payment {
                selectedContract = p.contract; amount = p.amount; paidAmount = p.paidAmount
                dueDate = p.dueDate; paidDate = p.paidDate; month = p.month; year = p.year
                status = p.status; notes = p.notes; hasPaidDate = p.paidDate != nil
                isExpense = p.isExpense
            }
        }
    }

    private func save() {
        // Enforce paidAmount/status consistency
        let resolvedPaidAmount: Double
        let resolvedPaidDate: Date?
        switch status {
        case .paid:
            resolvedPaidAmount = amount
            resolvedPaidDate = hasPaidDate ? (paidDate ?? Date()) : Date()
        case .partial:
            resolvedPaidAmount = min(paidAmount, amount)
            resolvedPaidDate = hasPaidDate ? (paidDate ?? Date()) : nil
        case .pending, .overdue:
            resolvedPaidAmount = 0
            resolvedPaidDate = nil
        }

        if let p = payment {
            p.contract = selectedContract; p.amount = amount
            p.paidAmount = resolvedPaidAmount; p.isExpense = isExpense
            p.dueDate = dueDate; p.paidDate = resolvedPaidDate
            p.month = month; p.year = year; p.status = status; p.notes = notes
        } else {
            let p = RentPayment(amount: amount, dueDate: dueDate, month: month, year: year, notes: notes)
            p.contract = selectedContract
            p.status = status; p.isExpense = isExpense
            p.paidAmount = resolvedPaidAmount
            p.paidDate = resolvedPaidDate
            modelContext.insert(p)
        }
        try? modelContext.save(); dismiss()
    }
}

// MARK: - Summary Chip

struct PaymentSummaryChip: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(count)").font(.title3.bold())
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
