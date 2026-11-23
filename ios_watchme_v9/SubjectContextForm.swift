//
//  SubjectContextForm.swift
//  ios_watchme_v9
//
//  What the people around a subject enter so the analysis can read a recording in context
//  (platform docs/product/context-layers.md, layer 0): what the subject is called and when they
//  were born, what the people around them are troubled by, who is at home with them and what
//  home is like, and who this account is to the subject.
//
//  Stored in subjects (birth_date, concerns, household.called), subject_places (the home:
//  people, about) and subject_members (relation, called; through set_my_subject_context).
//  The first version shows the home only; other kinds of places exist in the database.
//

import SwiftUI
import Supabase

/// One person who is at home with the subject. Fields the form does not edit (name, reading,
/// gender) are kept as they were stored.
struct PlacePerson: Identifiable, Equatable {
    let id = UUID()
    var called: String = ""        // "ママ、お母さん"
    var relation: String = ""      // "母", "姉"
    var isChild = false
    var birthDate: Date?
    var stored: [String: JSONValue] = [:]

    static func == (a: PlacePerson, b: PlacePerson) -> Bool {
        a.called == b.called && a.relation == b.relation && a.isChild == b.isChild
            && a.birthDate == b.birthDate && a.stored == b.stored
    }

    init() {}

    init(json: [String: JSONValue]) {
        stored = json
        if case .array(let names)? = json["called"] {
            called = names.compactMap { if case .string(let s) = $0 { return s } else { return nil } }.joined(separator: "、")
        }
        if case .string(let r)? = json["relation"] { relation = r }
        if case .string(let role)? = json["role"] { isChild = role == "other_child" }
        if case .string(let d)? = json["birth_date"] { birthDate = SubjectContextForm.dayFormatter.date(from: d) }
    }

    var json: JSONValue {
        var object = stored
        object["called"] = .array(SubjectContextForm.names(called).map { .string($0) })
        object["relation"] = relation.trimmingCharacters(in: .whitespaces).isEmpty ? .null : .string(relation.trimmingCharacters(in: .whitespaces))
        object["role"] = .string(isChild ? "other_child" : "adult")
        object["birth_date"] = (isChild ? birthDate : nil).map { .string(SubjectContextForm.dayFormatter.string(from: $0)) } ?? .null
        return .object(object)
    }

    /// "あーちゃん・姉・子ども（8歳）"
    var summary: String {
        var parts = [SubjectContextForm.names(called).first, relation.isEmpty ? nil : relation].compactMap { $0 }
        if isChild, let birthDate, let years = SubjectContextForm.age(from: birthDate) {
            parts.append("子ども（\(years)歳）")
        } else {
            parts.append(isChild ? "子ども" : "大人")
        }
        return parts.joined(separator: "・")
    }
}

@MainActor
final class SubjectContextForm: ObservableObject {
    // The subject
    @Published var calledNames = ""          // "せいげん、せいちゃん"
    @Published var birthDate: Date?
    @Published var concerns = ""
    // The home
    @Published var people: [PlacePerson] = []
    @Published var homeAbout = ""
    // This account
    @Published var myRelation = ""           // one of relationOptions' keys
    @Published var myCalled = ""

    @Published private(set) var isMember = false
    @Published private(set) var loaded = false

    private var household: [String: JSONValue] = [:]
    private var homePlaceId: String?
    private var myPlaceId: String?
    private var snapshot = ""

    nonisolated static let relationOptions: [(key: String, label: String)] = [
        ("mother", "母"), ("father", "父"), ("grandparent", "祖父母"), ("sibling", "きょうだい"),
        ("guardian", "保護者"), ("other", "そのほか"),
    ]

    nonisolated static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    nonisolated static func names(_ text: String) -> [String] {
        text.split(whereSeparator: { "、,，".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    nonisolated static func age(from birthDate: Date) -> Int? {
        Calendar(identifier: .gregorian).dateComponents([.year], from: birthDate, to: Date()).year
    }

    var relationLabel: String {
        Self.relationOptions.first { $0.key == myRelation }?.label
            ?? (myRelation.isEmpty ? "" : "そのほか")
    }

    private var state: String {
        [calledNames, birthDate.map(Self.dayFormatter.string) ?? "", concerns, homeAbout, myRelation, myCalled,
         people.map { "\($0.called)|\($0.relation)|\($0.isChild)|\($0.birthDate?.timeIntervalSince1970 ?? 0)" }.joined(separator: ";")]
            .joined(separator: "\u{1F}")
    }

    var hasChanges: Bool { loaded && state != snapshot }

    private struct SubjectRow: Decodable {
        let birth_date: String?
        let concerns: String?
        let household: JSONValue?
    }
    private struct PlaceRow: Decodable {
        let place_id: String
        let kind: String
        let people: JSONValue?
        let about: String?
    }
    private struct MemberRow: Decodable {
        let relation: String?
        let called: String?
        let place_id: String?
    }

    func load(subjectId: String) async {
        let client = SupabaseClientManager.shared.client
        do {
            let subjects: [SubjectRow] = try await client.from("subjects")
                .select("birth_date, concerns, household").eq("subject_id", value: subjectId).execute().value
            if let row = subjects.first {
                birthDate = row.birth_date.flatMap { Self.dayFormatter.date(from: String($0.prefix(10))) }
                concerns = row.concerns ?? ""
                if case .object(let object)? = row.household { household = object }
                if case .array(let names)? = household["called"] {
                    calledNames = names.compactMap { if case .string(let s) = $0 { return s } else { return nil } }.joined(separator: "、")
                }
            }
            let places: [PlaceRow] = try await client.from("subject_places")
                .select("place_id, kind, people, about").eq("subject_id", value: subjectId)
                .order("created_at", ascending: true).execute().value
            if let home = places.first(where: { $0.kind == "home" }) ?? places.first {
                homePlaceId = home.place_id
                homeAbout = home.about ?? ""
                if case .array(let list)? = home.people {
                    people = list.compactMap { if case .object(let o) = $0 { return PlacePerson(json: o) } else { return nil } }
                }
            }
            // Row level security returns only this account's membership.
            let members: [MemberRow] = try await client.from("subject_members")
                .select("relation, called, place_id").eq("subject_id", value: subjectId).execute().value
            if let me = members.first {
                isMember = true
                myRelation = me.relation ?? ""
                myCalled = me.called ?? ""
                myPlaceId = me.place_id
            }
        } catch {
            print("❌ [SubjectContext] load failed: \(error)")
        }
        snapshot = state
        loaded = true
    }

    /// A subject that does not exist yet: nothing to load, the form starts empty.
    func prepareNew() {
        guard !loaded else { return }
        snapshot = state
        loaded = true
    }

    private struct SubjectUpdate: Encodable {
        let birth_date: String?
        let age: Int?
        let concerns: String?
        let household: JSONValue
        let writesAge: Bool

        enum CodingKeys: String, CodingKey { case birth_date, age, concerns, household }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(birth_date, forKey: .birth_date)   // nil is written as null
            try c.encode(concerns, forKey: .concerns)
            try c.encode(household, forKey: .household)
            if writesAge { try c.encode(age, forKey: .age) }
        }
    }
    private struct PlaceUpdate: Encodable {
        let people: JSONValue
        let about: String?
        let updated_at: String

        enum CodingKeys: String, CodingKey { case people, about, updated_at }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(people, forKey: .people)
            try c.encode(about, forKey: .about)
            try c.encode(updated_at, forKey: .updated_at)
        }
    }
    private struct MyContext: Encodable {
        let p_subject_id: String
        let p_relation: String?
        let p_called: String?
        let p_place_id: String?

        enum CodingKeys: String, CodingKey { case p_subject_id, p_relation, p_called, p_place_id }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(p_subject_id, forKey: .p_subject_id)
            try c.encode(p_relation, forKey: .p_relation)
            try c.encode(p_called, forKey: .p_called)
            try c.encode(p_place_id, forKey: .p_place_id)
        }
    }

    /// Save what this account may change: everything for someone who can edit the subject,
    /// only "about you" for a view-only member.
    func save(subjectId: String, canEditSubject: Bool) async throws {
        let client = SupabaseClientManager.shared.client
        if canEditSubject {
            var updatedHousehold = household
            updatedHousehold["called"] = .array(Self.names(calledNames).map { .string($0) })
            let trimmedConcerns = concerns.trimmingCharacters(in: .whitespacesAndNewlines)
            try await client.from("subjects").update(SubjectUpdate(
                birth_date: birthDate.map(Self.dayFormatter.string),
                age: birthDate.flatMap(Self.age),
                concerns: trimmedConcerns.isEmpty ? nil : trimmedConcerns,
                household: .object(updatedHousehold),
                writesAge: birthDate != nil
            )).eq("subject_id", value: subjectId).execute()
            household = updatedHousehold

            if homePlaceId == nil {
                // A subject made a moment ago: its home was created with it.
                let places: [PlaceRow] = try await client.from("subject_places")
                    .select("place_id, kind, people, about").eq("subject_id", value: subjectId).execute().value
                homePlaceId = (places.first(where: { $0.kind == "home" }) ?? places.first)?.place_id
            }
            if let homePlaceId {
                let trimmedAbout = homeAbout.trimmingCharacters(in: .whitespacesAndNewlines)
                try await client.from("subject_places").update(PlaceUpdate(
                    people: .array(people.map(\.json)),
                    about: trimmedAbout.isEmpty ? nil : trimmedAbout,
                    updated_at: ISO8601DateFormatter().string(from: Date())
                )).eq("place_id", value: homePlaceId).execute()
            }
        }
        if isMember || canEditSubject {
            let trimmedCalled = myCalled.trimmingCharacters(in: .whitespaces)
            try await client.rpc("set_my_subject_context", params: MyContext(
                p_subject_id: subjectId,
                p_relation: myRelation.isEmpty ? nil : myRelation,
                p_called: trimmedCalled.isEmpty ? nil : trimmedCalled,
                p_place_id: myPlaceId ?? homePlaceId
            )).execute()
            isMember = true
        }
        snapshot = state
    }
}

// MARK: - Sections of the subject form

/// What the subject is called and when they were born (inside "基本情報").
struct SubjectIdentityFields: View {
    @ObservedObject var form: SubjectContextForm
    let disabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("呼ばれ方")
            AppTextField("例：せいげん、せいちゃん", text: $form.calledNames)
                .disabled(disabled)
            Text("ふだん呼ばれている名前。複数あるときは「、」で区切ります")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("生年月日")
            OptionalDateField(date: $form.birthDate, disabled: disabled)
        }
    }
}

/// A date that may be unset.
struct OptionalDateField: View {
    @Binding var date: Date?
    let disabled: Bool

    var body: some View {
        HStack {
            if let current = date {
                DatePicker("", selection: Binding(get: { current }, set: { date = $0 }),
                           in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .disabled(disabled)
                if let years = SubjectContextForm.age(from: current) {
                    Text("\(years)歳")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !disabled {
                    Button("消す") { date = nil }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Button(disabled ? "未設定" : "生年月日を設定") {
                    date = Calendar(identifier: .gregorian).date(byAdding: .year, value: -6, to: Date())
                }
                .font(.subheadline)
                .foregroundColor(disabled ? .secondary : .accentTeal)
                .disabled(disabled)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

/// Concerns, the people at home, what home is like, and who this account is.
struct SubjectContextSections: View {
    @ObservedObject var form: SubjectContextForm
    /// Someone who can edit the subject; a view-only member edits "about you" only.
    let canEditSubject: Bool
    @State private var editingPerson: PlacePerson?

    var body: some View {
        VStack(spacing: 24) {
            section("困っていること・見たいこと",
                    caption: "いま気になっていること、録音から知りたいことを書いてください。分析が何に注目するかの手がかりになります") {
                AppTextField("例：何度言っても動かず、つい強く叱ってしまう。叱る回数を減らしたい",
                             text: $form.concerns, axis: .vertical)
                    .lineLimit(3...6)
                    .disabled(!canEditSubject)
            }

            section("家庭で一緒にいる人", caption: "録音に声が入る人を登録すると、誰が話しているかを分けやすくなります") {
                VStack(spacing: 8) {
                    ForEach(form.people) { person in
                        Button {
                            if canEditSubject { editingPerson = person }
                        } label: {
                            HStack {
                                Text(person.summary)
                                    .foregroundColor(.primary)
                                Spacer()
                                if canEditSubject {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    if canEditSubject {
                        Button {
                            editingPerson = PlacePerson()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("人を追加")
                            }
                            .font(.subheadline)
                            .foregroundColor(.accentTeal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        }
                    } else if form.people.isEmpty {
                        Text("未登録")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            section("家庭の様子", caption: "間取りや、平日の流れなど") {
                AppTextField("例：リビングは2階。平日の朝は、朝食、着替え、登校の支度の順",
                             text: $form.homeAbout, axis: .vertical)
                    .lineLimit(3...6)
                    .disabled(!canEditSubject)
            }

            if form.isMember || canEditSubject {
                section("あなたについて", caption: "録音の中のあなたの声を見分ける手がかりになります") {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("この人との関係")
                        Menu {
                            Button("選択しない") { form.myRelation = "" }
                            ForEach(SubjectContextForm.relationOptions, id: \.key) { option in
                                Button(option.label) { form.myRelation = option.key }
                            }
                        } label: {
                            HStack {
                                Text(form.myRelation.isEmpty ? "選択してください" : form.relationLabel)
                                    .foregroundColor(form.myRelation.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("あなたの呼ばれ方")
                        AppTextField("例：パパ", text: $form.myCalled)
                    }
                }
            }
        }
        .sheet(item: $editingPerson) { person in
            PlacePersonEditor(
                person: person,
                isNew: !form.people.contains { $0.id == person.id },
                onSave: { saved in
                    if let index = form.people.firstIndex(where: { $0.id == saved.id }) {
                        form.people[index] = saved
                    } else {
                        form.people.append(saved)
                    }
                },
                onDelete: { form.people.removeAll { $0.id == person.id } }
            )
        }
    }

    private func section<Content: View>(_ title: String, caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 12) {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
                content()
            }
        }
    }
}

private func fieldLabel(_ text: String) -> some View {
    Text(text)
        .font(.subheadline)
        .fontWeight(.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
}

/// Add or edit one person at home.
struct PlacePersonEditor: View {
    @State var person: PlacePerson
    let isNew: Bool
    let onSave: (PlacePerson) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("呼ばれ方")
                        AppTextField("例：ママ、お母さん", text: $person.called)
                        Text("複数あるときは「、」で区切ります")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("関係")
                        AppTextField("例：母、姉、祖母", text: $person.relation)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("大人か子どもか")
                        Picker("", selection: $person.isChild) {
                            Text("大人").tag(false)
                            Text("子ども").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                    if person.isChild {
                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel("生年月日")
                            OptionalDateField(date: $person.birthDate, disabled: false)
                        }
                    }
                    if !isNew {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("この人を外す")
                            }
                            .font(.subheadline)
                            .foregroundColor(.accentCoral)
                            .padding(.top, 12)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(isNew ? "人を追加" : "人を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isNew ? "追加" : "完了") {
                        onSave(person)
                        dismiss()
                    }
                    .disabled(SubjectContextForm.names(person.called).isEmpty
                              && person.relation.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
