import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var apartments: [Apartment]
    @Query private var contracts: [Contract]
    @Query private var tenants: [Tenant]
    @Query private var payments: [RentPayment]
    @Environment(\.loc) var loc

    var activeContracts: [Contract] { contracts.filter { $0.status == .active && !$0.isExpired } }
    var overduePayments: [RentPayment] { payments.filter { $0.status == .overdue } }
    var expiringSoon: [Contract] { contracts.filter { $0.isExpiringSoon } }
    var totalMonthlyRevenue: Double { activeContracts.reduce(0) { $0 + $1.rentAmount } }

    var recentPayments: [(label: String, paid: Double, pending: Double)] {
        let groups = Dictionary(grouping: payments) { "\($0.year)-\(String(format: "%02d", $0.month))" }
        return groups.sorted { $0.key < $1.key }.suffix(6).map { key, items in
            let month = items[0].month
            let year = items[0].year
            let paid = items.filter { $0.status == .paid }.reduce(0) { $0 + $1.paidAmount }
            let pending = items.filter { $0.status != .paid }.reduce(0) { $0 + $1.amount }
            return (label: "\(month)/\(year)", paid: paid, pending: pending)
        }
    }

    var aptStatusData: [(status: ApartmentStatus, count: Int)] {
        ApartmentStatus.allCases.compactMap { status in
            let count = apartments.filter { $0.status == status }.count
            return count > 0 ? (status: status, count: count) : nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: — Stat Cards
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190))], spacing: 14) {
                    StatCard(
                        title: loc.t("dash.total_apartments"),
                        value: "\(apartments.count)",
                        subtitle: "\(apartments.filter { $0.status == .rented }.count) \(loc.t("apt.status.rented").lowercased())",
                        icon: "building.2.fill",
                        accent: .blue
                    )
                    StatCard(
                        title: loc.t("dash.active_contracts"),
                        value: "\(activeContracts.count)",
                        subtitle: "\(expiringSoon.count) \(loc.t("contract.expiring_soon").lowercased())",
                        icon: "doc.text.fill",
                        accent: .green
                    )
                    StatCard(
                        title: loc.t("dash.total_tenants"),
                        value: "\(tenants.count)",
                        subtitle: "",
                        icon: "person.2.fill",
                        accent: .purple
                    )
                    StatCard(
                        title: loc.t("dash.monthly_revenue"),
                        value: totalMonthlyRevenue.formatted(.currency(code: "EUR")),
                        subtitle: "",
                        icon: "eurosign.circle.fill",
                        accent: .orange
                    )
                    StatCard(
                        title: loc.t("rent.status.overdue"),
                        value: "\(overduePayments.count)",
                        subtitle: "",
                        icon: "exclamationmark.triangle.fill",
                        accent: overduePayments.isEmpty ? .green : .red
                    )
                    StatCard(
                        title: loc.t("rent.payments"),
                        value: "\(payments.count)",
                        subtitle: "\(payments.filter { $0.status == .paid }.count) \(loc.t("rent.status.paid").lowercased())",
                        icon: "checkmark.circle.fill",
                        accent: .teal
                    )
                }

                HStack(alignment: .top, spacing: 16) {
                    // MARK: — Revenue Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Label(loc.t("dash.revenue_chart"), systemImage: "chart.bar.fill")
                            .font(.headline)

                        if recentPayments.isEmpty {
                            ContentUnavailableView(
                                loc.t("rent.no_data"),
                                systemImage: "eurosign.circle",
                                description: Text("")
                            )
                            .frame(height: 180)
                        } else {
                            Chart {
                                ForEach(recentPayments, id: \.label) { item in
                                    BarMark(
                                        x: .value("Month", item.label),
                                        y: .value("Paid", item.paid)
                                    )
                                    .foregroundStyle(Color.green.gradient)

                                    BarMark(
                                        x: .value("Month", item.label),
                                        y: .value("Pending", item.pending)
                                    )
                                    .foregroundStyle(Color.orange.opacity(0.5).gradient)
                                }
                            }
                            .chartLegend(position: .topTrailing)
                            .frame(height: 180)
                        }
                    }
                    .padding()
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // MARK: — Apartment Status Donut
                    VStack(alignment: .leading, spacing: 12) {
                        Label(loc.t("apt.status"), systemImage: "chart.pie.fill")
                            .font(.headline)

                        if aptStatusData.isEmpty {
                            ContentUnavailableView(
                                loc.t("dash.no_apartments"),
                                systemImage: "building.2",
                                description: Text(loc.t("dash.no_apartments_desc"))
                            )
                            .frame(height: 180)
                        } else {
                            Chart(aptStatusData, id: \.status) { item in
                                SectorMark(
                                    angle: .value("Count", item.count),
                                    innerRadius: .ratio(0.55),
                                    angularInset: 2
                                )
                                .foregroundStyle(by: .value("Status", item.status.rawValue))
                                .annotation(position: .overlay) {
                                    if item.count > 0 {
                                        Text("\(item.count)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .frame(height: 180)

                            // Legend
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                                ForEach(aptStatusData, id: \.status) { item in
                                    HStack(spacing: 4) {
                                        Circle().frame(width: 8, height: 8)
                                        Text(item.status.rawValue)
                                            .font(.caption)
                                        Spacer()
                                        Text("\(item.count)")
                                            .font(.caption.bold())
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(minWidth: 220)
                }

                // MARK: — Alerts
                if !expiringSoon.isEmpty || !overduePayments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(loc.t("dash.alerts"), systemImage: "bell.badge.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)

                        ForEach(expiringSoon, id: \.persistentModelID) { contract in
                            AlertRow(
                                icon: "calendar.badge.exclamationmark",
                                color: .orange,
                                message: String(format: loc.t("dash.contract_expires"),
                                    contract.contractNumber,
                                    contract.apartment?.displayName ?? "N/A",
                                    contract.endDate.formatted(date: .abbreviated, time: .omitted))
                            )
                        }
                        ForEach(overduePayments, id: \.persistentModelID) { payment in
                            AlertRow(
                                icon: "exclamationmark.triangle.fill",
                                color: .red,
                                message: String(format: loc.t("dash.overdue_payment"),
                                    payment.amount.formatted(.currency(code: "EUR")),
                                    payment.monthName)
                            )
                        }
                    }
                    .padding()
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle(loc.t("dash.title"))
    }
}

// MARK: — Subviews

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(accent)
                Spacer()
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AlertRow: View {
    let icon: String
    let color: Color
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
