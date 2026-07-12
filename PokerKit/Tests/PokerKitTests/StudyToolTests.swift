import Testing
@testable import PokerKit

@Test func allStudyToolsHaveTitleAndSummary() {
    for tool in StudyTool.allCases {
        #expect(!tool.title.isEmpty)
        #expect(!tool.summary.isEmpty)
    }
}

@Test func studyToolIdMatchesRawValue() {
    #expect(StudyTool.bankroll.id == StudyTool.bankroll.rawValue)
}
