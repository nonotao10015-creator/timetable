import SwiftUI

// MARK: - App

@main
struct TimetableApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - Data models (matches data/schedule.json)

struct ScheduleData: Decodable {
    let updated: String
    let title: String
    let term: String
    let grade: String
    let periods: [PeriodInfo]
    let weeks: [WeekInfo]
    let courses: [String: CourseInfo]
    let events: [Event]
}

struct PeriodInfo: Decodable, Identifiable {
    var id: Int { no }
    let no: Int
    let start: String
    let end: String
}

struct WeekInfo: Decodable, Identifiable {
    var id: Int { week }
    let week: Int
    let monday: String
}

struct CourseInfo: Decodable {
    let name: String
    let code: String
    let color: String
}

struct Event: Identifiable, Decodable, Hashable {
    let id: Int
    let date: String
    let week: Int
    let dow: Int
    let start: String
    let end: String
    let p0: Int
    let count: Int
    let course: String
    let code: String
    let room: String?
    let type: String?
    let teacher: String?
    let classCode: String?
    let className: String?
    let content: String?
    let bz: String?
    let courseText: String?
    let floor: String?
}

// MARK: - Color + date helpers

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xff) / 255
        let g = Double((value >> 8) & 0xff) / 255
        let b = Double(value & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "zh_CN")
    return f
}()

private func date(_ s: String) -> Date {
    dateFormatter.date(from: s) ?? Date()
}

private func addDays(_ d: Date, _ n: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: n, to: d) ?? d
}

private let dayNames = ["一", "二", "三", "四", "五", "六", "日"]

// MARK: - Root

struct RootView: View {
    @State private var data: ScheduleData?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let data {
                ScheduleHomeView(data: data)
            } else if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("课表数据读取失败")
                        .font(.headline)
                    Text(loadError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                ProgressView("正在读取课表…")
            }
        }
        .task {
            load()
        }
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "schedule", withExtension: "json") else {
            loadError = "App 内没有找到 schedule.json"
            return
        }
        do {
            let raw = try Data(contentsOf: url)
            data = try JSONDecoder().decode(ScheduleData.self, from: raw)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

// MARK: - Home / week pager

struct ScheduleHomeView: View {
    let data: ScheduleData
    @State private var selectedWeek = 1
    @State private var selectedEvent: Event?

    private var currentWeekIndex: Int {
        max(0, min(data.weeks.count - 1, selectedWeek - 1))
    }

    private var currentWeek: WeekInfo {
        data.weeks[currentWeekIndex]
    }

    init(data: ScheduleData) {
        self.data = data
        _selectedWeek = State(initialValue: Self.initialWeek(data))
    }

    static func initialWeek(_ data: ScheduleData) -> Int {
        let today = Date()
        for week in data.weeks {
            let start = date(week.monday)
            let end = addDays(start, 6)
            if today >= start && today <= end {
                return week.week
            }
        }
        if let first = data.weeks.first, today < date(first.monday) {
            return first.week
        }
        return data.weeks.last?.week ?? data.weeks.first?.week ?? 1
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $selectedWeek) {
                ForEach(data.weeks) { week in
                    WeekPage(data: data, week: week, onTap: { event in
                        selectedEvent = event
                    })
                    .tag(week.week)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(data: data, event: event)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthTitle(currentWeek.monday))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(data.grade.isEmpty ? data.term : data.grade)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("今天") {
                    withAnimation { selectedWeek = Self.initialWeek(data) }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(hex: "#E5484D"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#FDEBEC"))
                .clipShape(Capsule())
            }

            HStack {
                Button {
                    withAnimation { selectedWeek = max(1, selectedWeek - 1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 34, height: 34)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.07), radius: 2, y: 1)
                }
                Spacer()
                VStack(spacing: 1) {
                    Text("第 \(currentWeek.week) 周")
                        .font(.subheadline.bold())
                    Text(weekRange(currentWeek.monday))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation { selectedWeek = min(data.weeks.last?.week ?? 1, selectedWeek + 1) }
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 34, height: 34)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.07), radius: 2, y: 1)
                }
            }
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground).opacity(0.96))
    }

    private func monthTitle(_ monday: String) -> String {
        let c = Calendar.current.dateComponents([.month], from: date(monday))
        return "\(c.month ?? 0)月"
    }

    private func weekRange(_ monday: String) -> String {
        let start = date(monday)
        let end = addDays(start, 6)
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }
}

// MARK: - One week page

struct WeekPage: View {
    let data: ScheduleData
    let week: WeekInfo
    let onTap: (Event) -> Void

    private let rowH: CGFloat = 58
    private let lunchH: CGFloat = 26
    private let timeW: CGFloat = 46

    private var totalHeight: CGFloat {
        5 * rowH + lunchH + 8 * rowH
    }

    private func periodY(_ p: Int) -> CGFloat {
        p <= 5 ? CGFloat(p - 1) * rowH : 5 * rowH + lunchH + CGFloat(p - 6) * rowH
    }

    private var eventsByDate: [String: [Event]] {
        var map: [String: [Event]] = [:]
        for event in data.events where event.week == week.week {
            map[event.date, default: []].append(event)
        }
        return map
    }

    var body: some View {
        GeometryReader { outer in
            let dayW = max(0, (outer.size.width - timeW) / 7)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: timeW, height: 30)
                    ForEach(0..<7, id: \.self) { i in
                        dayHeader(i, width: dayW)
                    }
                }
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        timeColumn(width: timeW, total: totalHeight)
                        ForEach(0..<7, id: \.self) { i in
                            dayColumn(index: i, x: timeW + CGFloat(i) * dayW, width: dayW, total: totalHeight)
                        }
                    }
                    .frame(width: outer.size.width, height: totalHeight, alignment: .topLeading)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private func dayHeader(_ i: Int, width: CGFloat) -> some View {
        let d = addDays(date(week.monday), i)
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        let isToday = Calendar.current.isDateInToday(d)
        return VStack(spacing: 3) {
            Text(dayNames[i])
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(fmt.string(from: d))
                .font(.footnote.bold())
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .frame(minWidth: 26, minHeight: 26)
                .background(Circle().fill(isToday ? Color(hex: "#E5484D") : Color.clear))
        }
        .frame(width: width)
    }

    private func timeColumn(width: CGFloat, total: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(1...13, id: \.self) { p in
                VStack(spacing: 0) {
                    Text("\(p)")
                        .font(.system(size: 12, weight: .semibold))
                    Text(data.periods[p - 1].start)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(width: width, height: rowH)
                .offset(y: periodY(p))
            }
            Text("午休")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: width, height: lunchH)
                .background(Color(.systemGroupedBackground))
                .offset(y: 5 * rowH)
        }
        .frame(width: width, height: total)
    }

    private func dayColumn(index: Int, x: CGFloat, width: CGFloat, total: CGFloat) -> some View {
        let ds = isoDate(addDays(date(week.monday), index))
        let events = eventsByDate[ds] ?? []
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(.systemBackground))
                .frame(width: width, height: total)
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(width: 0.5, height: total)
            // lunch band
            Color.black.opacity(0.04)
                .frame(width: width, height: lunchH)
                .offset(y: 5 * rowH)
            ForEach(events) { event in
                EventBlock(event: event, color: color(for: event))
                    .frame(width: max(0, width - 4), height: CGFloat(event.count) * rowH - 6)
                    .offset(x: 2, y: periodY(event.p0) + 2)
                    .onTapGesture { onTap(event) }
            }
        }
        .frame(width: width, height: total, alignment: .topLeading)
        .offset(x: x)
        .clipped()
    }

    private func isoDate(_ d: Date) -> String {
        dateFormatter.string(from: d)
    }

    private func color(for event: Event) -> Color {
        if let c = data.courses[event.code] {
            return Color(hex: c.color)
        }
        return Color(hex: "#E4E4E9")
    }
}

// MARK: - Course card

struct EventBlock: View {
    let event: Event
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.course)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let room = shortRoom(event.room), !room.isEmpty {
                Text(room)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
    }

    private func shortRoom(_ s: String?) -> String? {
        guard var s else { return nil }
        s = s.replacingOccurrences(of: "浦东-", with: "")
        s = s.replacingOccurrences(of: "医学院-", with: "")
        return s
    }
}

// MARK: - Detail sheet

struct EventDetailView: View {
    let data: ScheduleData
    let event: Event
    @Environment(\.dismiss) private var dismiss

    private var rows: [(String, String?)] {
        [
            ("课程代码", event.code),
            ("课程类型", event.type),
            ("上课班级", clean(event.className ?? event.classCode)),
            ("教师", event.teacher),
            ("上课时间", event.courseText ?? periodText()),
            ("上课地点", event.room),
            ("课程内容", event.content),
            ("备注", event.bz)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("课程信息")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.white)
                    .clipShape(Capsule())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.06))
                        .clipShape(Circle())
                }
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(color(for: event))
                    .frame(width: 12, height: 12)
                Text(event.course)
                    .font(.title2.bold())
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.0) { row in
                        if let value = row.1, !value.isEmpty {
                            HStack(alignment: .top) {
                                Text(row.0)
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 14)
                                Text(value)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            if row.0 != rows.last?.0 {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .background(Color(.systemGroupedBackground))
    }

    private func color(for event: Event) -> Color {
        if let c = data.courses[event.code] { return Color(hex: c.color) }
        return .gray.opacity(0.4)
    }

    private func clean(_ s: String?) -> String? {
        guard let s else { return nil }
        let t = s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return t.isEmpty ? nil : t
    }

    private func periodText() -> String? {
        guard event.p0 > 0 else { return nil }
        let end = event.p0 + event.count - 1
        let period = end <= 5 ? "上午" : (end <= 9 ? "下午" : "晚上")
        return "星期\(dayNames[event.dow - 1]) \(period)第\(event.p0)-\(end)节"
    }
}
