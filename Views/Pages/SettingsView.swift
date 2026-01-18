import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // 直接绑定到 UserDefaults，不需要 ViewModel
    @AppStorage("isSoundOn") private var isSoundOn = true
    @AppStorage("isHapticOn") private var isHapticOn = true
    
    var body: some View {
        NavigationView {
            Form {
                // 1. 体验设置
                Section(header: Text("体验设置")) {
                    Toggle(isOn: $isSoundOn) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("音效")
                        }
                    }
                    // 开关变动时，如果有声音，不仅改变状态，最好立刻停止当前声音
                    .onChange(of: isSoundOn) { _, newValue in
                        if !newValue { AudioManager.shared.stopAll() }
                    }
                    
                    Toggle(isOn: $isHapticOn) {
                        HStack {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("震动反馈")
                        }
                    }
                }
                
                // 2. 关于与声明
                Section(header: Text("关于")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("彩票棒棒哒")
                            .font(.headline)
                        Text("版本 1.0.0")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("免责声明：")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text("本应用仅为随机数模拟生成工具，旨在提供娱乐体验。本应用不提供任何网络购彩服务，生成结果与官方彩票开奖结果无关。请用户理性对待，切勿沉迷。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark) // 保持深色风格
    }
}
