import SwiftUI

// MARK: - 历史记录页面
struct HistoryListView: View {
    @Environment(\.dismiss) var dismiss
    @State private var records: [LotteryResult] = []
    
    // 多选相关状态
    @State private var isSelectionMode = false
    @State private var selectedIds = Set<UUID>()
    
    // 复制成功的提示
    @State private var showCopyToast = false
    @State private var copyCount = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if records.isEmpty {
                    emptyView
                } else {
                    VStack(spacing: 0) {
                        // 列表区域
                        List {
                            ForEach(records) { record in
                                HStack(spacing: 12) {
                                    // 1. 复选框
                                    if isSelectionMode {
                                        Button(action: {
                                            toggleSelection(for: record.id)
                                        }) {
                                            Image(systemName: selectedIds.contains(record.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.title2)
                                                .foregroundColor(selectedIds.contains(record.id) ? .blue : .gray)
                                        }
                                        .buttonStyle(.plain)
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                    
                                    // 2. 原始记录行
                                    HistoryRow(record: record)
                                        .onTapGesture {
                                            if isSelectionMode {
                                                toggleSelection(for: record.id)
                                            }
                                        }
                                }
                                .listRowBackground(Color.white.opacity(0.1))
                                .listRowSeparator(.hidden)
                            }
                            .onDelete(perform: deleteItems)
                        }
                        .listStyle(.plain)
                        
                        // 3. 底部批量操作栏
                        if isSelectionMode {
                            VStack {
                                Divider().background(Color.gray)
                                HStack {
                                    Button("全选") {
                                        if selectedIds.count == records.count {
                                            selectedIds.removeAll()
                                        } else {
                                            selectedIds = Set(records.map { $0.id })
                                        }
                                    }
                                    .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Button(action: copySelectedItems) {
                                        HStack {
                                            Image(systemName: "doc.on.doc")
                                            Text("复制已选 (\(selectedIds.count))")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Capsule().fill(selectedIds.isEmpty ? Color.gray : Color.blue))
                                    }
                                    .disabled(selectedIds.isEmpty)
                                }
                                .padding()
                                .background(Color(hex: "1C1C1E"))
                            }
                            .transition(.move(edge: .bottom))
                        }
                    }
                }
                
                // 复制成功提示
                if showCopyToast {
                    VStack {
                        Spacer()
                        Text("成功复制 \(copyCount) 条记录")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Capsule().fill(Color.gray.opacity(0.9)))
                            .padding(.bottom, 50)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .zIndex(100)
                }
            }
            .navigationTitle("开奖历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button("取消") {
                            withAnimation {
                                isSelectionMode = false
                                selectedIds.removeAll()
                            }
                        }
                    } else {
                        Button(role: .destructive, action: {
                            HistoryManager.shared.clear()
                            records = []
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectionMode {
                        EmptyView()
                    } else {
                        HStack {
                            Button(action: {
                                withAnimation { isSelectionMode = true }
                            }) {
                                Text("选择")
                            }
                            Button("关闭") { dismiss() }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            records = HistoryManager.shared.loadAll()
        }
    }
    
    // MARK: - 逻辑方法
    
    var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("暂无开奖记录").foregroundColor(.gray)
        }
    }
    
    func toggleSelection(for id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        // 暂不支持左滑删除，防止逻辑冲突
    }
    
    func copySelectedItems() {
        let selectedRecords = records.filter { selectedIds.contains($0.id) }
        if selectedRecords.isEmpty { return }
        
        let copyString = selectedRecords.map { record in
            "\(record.type.rawValue): \(record.displayString)"
        }.joined(separator: "\n")
        
        UIPasteboard.general.string = copyString
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        copyCount = selectedRecords.count
        withAnimation {
            showCopyToast = true
            isSelectionMode = false
            selectedIds.removeAll()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopyToast = false }
        }
    }
}

// MARK: - 单行历史记录视图
struct HistoryRow: View {
    let record: LotteryResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(record.type.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.gray.opacity(0.3)))
                
                Spacer()
                
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack {
                ForEach(record.primaryBalls, id: \.self) { ball in
                    MiniBallView(text: "\(ball.number)", color: .red)
                }
                
                if let blues = record.secondaryBalls, !blues.isEmpty {
                    Text("+")
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    ForEach(blues, id: \.self) { ball in
                        MiniBallView(text: "\(ball.number)", color: .blue)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "1C1C1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.vertical, 4)
    }
}

// MARK: - 迷你小球组件
struct MiniBallView: View {
    let text: String
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [color.opacity(0.8), color], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 28, height: 28)
        .shadow(color: color.opacity(0.5), radius: 2, x: 0, y: 1)
    }
}
