import SwiftUI
import SwiftData
import Charts

struct ActivityDetailView: View {
    // Получаем данные напрямую из базы
    @Query(sort: \DailyActivity.date, order: .reverse) var activities: [DailyActivity]
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            List {
                // ГРАФИК ЗА 30 ДНЕЙ
                Section {
                    Chart {
                        ForEach(activities.prefix(30), id: \.date) { activity in
                            BarMark(
                                x: .value("Дата", activity.date, unit: .day),
                                y: .value("XP", activity.xpEarned)
                            )
                            .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .bottom, endPoint: .top))
                        }
                    }
                    .frame(height: 250)
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Последние 30 дней".localized)
                }
                
                // ИСТОРИЯ ПО ДНЯМ
                Section("История".localized) {
                    if activities.isEmpty {
                        Text("Пока нет активности".localized).foregroundStyle(.secondary)
                    } else {
                        ForEach(activities) { activity in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(activity.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.headline)
                                    Text("Тренировка".localized)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("+\(activity.xpEarned) XP")
                                    .font(.body).bold().foregroundStyle(.purple)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Боевая активность".localized)
    }
}
