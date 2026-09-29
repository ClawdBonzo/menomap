import SwiftUI

struct LearnView: View {
    @State private var query = ""
    @State private var asked: AskAnswer?
    private let ask = AskMenoMapService()

    var body: some View {
        let results = ask.search(query)
        List {
            Section {
                DisclaimerBanner(compact: true).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            if let asked {
                Section("Answer") { AskAnswerView(answer: asked) }
            }
            if !results.faqs.isEmpty && !query.isEmpty {
                Section("Questions") {
                    ForEach(results.faqs, id: \.self) { f in
                        Button { asked = .matched(faq: f, article: ArticleLibrary.article(id: f.articleID)) } label: {
                            Text(f.question).foregroundStyle(MenoTheme.ink)
                        }
                    }
                }
            }
            Section(query.isEmpty ? "Library" : "Articles") {
                ForEach(results.articles) { a in
                    NavigationLink { ArticleView(article: a) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: a.symbol).foregroundStyle(MenoTheme.teal).frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(a.title).font(.headline).foregroundStyle(MenoTheme.ink)
                                Text(a.summary).font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            if query.isEmpty {
                Section("Common questions") {
                    ForEach(FAQLibrary.all.prefix(6), id: \.self) { f in
                        Button { asked = ask.answer(f.question) } label: { Text(f.question).foregroundStyle(MenoTheme.ink) }
                    }
                }
            }
        }
        .menoScreen()
        .navigationTitle("Learn")
        .searchable(text: $query, prompt: Text("Ask MenoMap, e.g. why 3am waking?"))
        .onSubmit(of: .search) { asked = ask.answer(query) }
    }
}

struct AskAnswerView: View {
    let answer: AskAnswer

    var body: some View {
        switch answer {
        case .matched(let faq, let article):
            VStack(alignment: .leading, spacing: 10) {
                Text(faq.question).font(.headline)
                Text(faq.answer).font(.body)
                if let article {
                    NavigationLink { ArticleView(article: article) } label: {
                        Label("Read: \(article.title)", systemImage: "book").font(.subheadline.weight(.semibold))
                    }
                }
            }
            .padding(.vertical, 4)
        case .fallback(let text):
            Text(text).font(.body).padding(.vertical, 4)
        }
    }
}

struct ArticleView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title).font(MenoTheme.headline(.largeTitle)).foregroundStyle(MenoTheme.ink)
                Text(article.summary).font(.title3).foregroundStyle(MenoTheme.inkSecondary)
                ForEach(Array(article.body.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, para in
                    Text(LocalizedStringKey(para)).font(.body).foregroundStyle(MenoTheme.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                if let source = article.sourceName {
                    if let url = article.sourceURL {
                        Link("Source: \(source)", destination: url).font(.footnote)
                    } else {
                        Text("Based on public guidance from \(source).").font(.footnote).foregroundStyle(MenoTheme.inkSecondary)
                    }
                }
                if let reviewed = article.reviewedAt, !article.needsSourceReview, article.sourceURL != nil {
                    Text("Sources checked \(reviewed.formatted(date: .abbreviated, time: .omitted))").font(.footnote).foregroundStyle(MenoTheme.inkSecondary)
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .menoScreen()
        .navigationBarTitleDisplayMode(.inline)
    }
}
