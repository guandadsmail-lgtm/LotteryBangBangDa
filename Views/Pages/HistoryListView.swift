
import SwiftUI

struct HistoryListView: View {
    @Environment(\.dismiss) var dismiss
    @State private var historyRecords: [LotteryResult] = []
    
    // 多选相关
    @State private var selectedRecordIds = Set<UUID>()
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "050505").ignoresSafeArea()
                
                if historyRecords.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("暂无开奖记录")
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack {
                        List(selection: $selectedRecordIds) {
                            ForEach(historyRecords) { record in
                                HistoryRow(record: record)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                                    .tag(record.id)
                            }
                        }
                        .listStyle(.plain)
                        .environment(\.editMode, $editMode)
                        
                        if editMode == .active && !selectedRecordIds.isEmpty {
                            HStack {
                                Text("已选 \(selectedRecordIds.count) 条")
                                    .foregroundColor(.gray)
                                Spacer()
                                Button(action: copySelected) {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                        Text("复制选中")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                }
                            }
                            .padding()
                            .background(Color(hex: "1C1C1E"))
                        }
                    }
                }
            }
            .navigationTitle("历史记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !historyRecords.isEmpty {
                            Button(editMode == .active ? "完成" : "选择") {
                                withAnimation {
                                    editMode = editMode == .active ? .inactive : .active
                                    selectedRecordIds.removeAll()
                                }
                            }
                        }
                        
                        if editMode == .inactive {
                            Button {
                                HistoryManager.shared.clear()
                                loadData()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    func loadData() {
        historyRecords = HistoryManager.shared.loadAll()
    }
    
    func copySelected() {
        let selected = historyRecords.filter { selectedRecordIds.contains($0.id) }
        let text = selected.map { $0.displayString }.joined(separator: "\n")
        UIPasteboard.general.string = text
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation {
            editMode = .inactive
            selectedRecordIds.removeAll()
        }
    }
}

struct HistoryRow: View {
    let record: LotteryResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                BadgeLabel(text: record.type.displayName, color: themeColor)
                                
                                Spacer()
                                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 8) {
                // 🔴 红球 (使用 .lotteryRed)
                ForEach(record.primaryBalls, id: \.self) { number in
                    MiniBall(number: number, color: .lotteryRed)
                }
                
                // 🔵 蓝球 (使用 .lotteryBlue)
                if let blues = record.secondaryBalls, !blues.isEmpty {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 20)
                    
                    ForEach(blues, id: \.self) { number in
                        MiniBall(number: number, color: .lotteryBlue)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "1C1C1E"))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .contextMenu {
            Button {
                UIPasteboard.general.string = record.displayString
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
        }
    }
    
    var themeColor: Color {
        switch record.type.style {
        case .bigMixer: return .blue
        case .slotMachine: return .red
        }
    }
}

struct BadgeLabel: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(.caption.bold()).foregroundColor(color).padding(.horizontal, 8).padding(.vertical, 4).background(color.opacity(0.2)).cornerRadius(8)
    }
}

struct MiniBall: View {
    let number: Int
    let color: Color
    var body: some View {
        ZStack {
            // 使用统一的 color
            Circle().fill(LinearGradient(colors: [color.opacity(0.9), color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(String(format: "%02d", number)).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white)
        }
        .frame(width: 28, height: 28)
    }
}

