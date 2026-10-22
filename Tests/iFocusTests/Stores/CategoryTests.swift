import XCTest
@testable import iFocus
import iFocusCore

final class CategoryTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-CategoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    func testBuiltInCategoryStillEncodesAsLegacyName() throws {
        let data = try JSONEncoder().encode(TaskCategory.study)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"学习\"")

        let decoded = try JSONDecoder().decode(TaskCategory.self, from: data)
        XCTAssertEqual(decoded, .study)
    }

    func testCustomCategoryRoundTripsWithTask() throws {
        let store = TaskStore(storageDirectory: tempDir)
        let category = try XCTUnwrap(success(
            store.addCustomCategory(name: "阅读", colorHex: "#EC4899", icon: "book.fill")
        ))

        store.newTaskTitle = "读完一章"
        store.newTaskCategory = category
        store.addTask(for: .todayTask)

        XCTAssertEqual(store.tasks.first?.category, category)

        let reloaded = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(reloaded.customCategories, [category])
        XCTAssertEqual(reloaded.tasks.first?.category, category)
        XCTAssertEqual(reloaded.allCategories.map(\.name), ["工作", "学习", "生活", "重要", "家", "其他", "阅读"])
    }

    func testUpdatingCategoryAppliesToTasksAndHistory() throws {
        let store = TaskStore(storageDirectory: tempDir)
        let category = try XCTUnwrap(success(
            store.addCustomCategory(name: "阅读", colorHex: "#EC4899", icon: "book.fill")
        ))

        store.newTaskTitle = "读完一章"
        store.newTaskCategory = category
        let taskID = try XCTUnwrap(store.addTask(for: .todayTask))
        store.logFocusSession(
            taskId: taskID,
            taskTitle: "读完一章",
            taskCategory: category,
            minutes: 25
        )

        let updated = try XCTUnwrap(success(
            store.updateCustomCategory(
                id: category.id,
                name: "深度阅读",
                colorHex: "#14B8A6",
                icon: "graduationcap.fill"
            )
        ))
        XCTAssertEqual(updated.name, "深度阅读")
        XCTAssertEqual(store.tasks.first?.category, updated)
        XCTAssertEqual(store.focusSessions.first?.taskCategory, updated)

        let reloaded = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(reloaded.customCategories, [updated])
        XCTAssertEqual(reloaded.tasks.first?.category, updated)
        XCTAssertEqual(reloaded.focusSessions.first?.taskCategory, updated)
    }

    func testDeletingCategoryMovesTasksAndHistoryToOther() throws {
        let store = TaskStore(storageDirectory: tempDir)
        let category = try XCTUnwrap(success(
            store.addCustomCategory(name: "副业", colorHex: "#F59E0B", icon: "lightbulb.fill")
        ))
        store.newTaskTitle = "写产品文档"
        store.newTaskCategory = category
        let taskID = try XCTUnwrap(store.addTask(for: .todayTask))
        store.logFocusSession(
            taskId: taskID,
            taskTitle: "写产品文档",
            taskCategory: category,
            minutes: 30
        )

        XCTAssertTrue(store.deleteCustomCategory(id: category.id))
        XCTAssertTrue(store.customCategories.isEmpty)
        XCTAssertEqual(store.tasks.first?.category, .other)
        XCTAssertEqual(store.focusSessions.first?.taskCategory, .other)
        XCTAssertEqual(store.newTaskCategory, .study)

        let reloaded = TaskStore(storageDirectory: tempDir)
        XCTAssertTrue(reloaded.customCategories.isEmpty)
        XCTAssertEqual(reloaded.tasks.first?.category, .other)
        XCTAssertEqual(reloaded.focusSessions.first?.taskCategory, .other)
    }

    func testCategoryValidationRejectsBlanksDuplicatesAndLongNames() throws {
        let store = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(
            store.addCustomCategory(name: "   ", colorHex: "#3B82F6", icon: "tag.fill"),
            .failure(.emptyName)
        )
        XCTAssertEqual(
            store.addCustomCategory(name: "工作", colorHex: "#3B82F6", icon: "tag.fill"),
            .failure(.duplicateName)
        )

        let category = try XCTUnwrap(success(
            store.addCustomCategory(name: "阅读", colorHex: "#3B82F6", icon: "tag.fill")
        ))
        XCTAssertEqual(category.name, "阅读")
        XCTAssertEqual(
            store.addCustomCategory(name: " 阅读 ", colorHex: "#3B82F6", icon: "tag.fill"),
            .failure(.duplicateName)
        )
        XCTAssertEqual(
            store.addCustomCategory(
                name: String(repeating: "长", count: TaskCategory.maxNameLength + 1),
                colorHex: "#3B82F6",
                icon: "tag.fill"
            ),
            .failure(.nameTooLong)
        )
        XCTAssertFalse(store.deleteCustomCategory(id: TaskCategory.study.id))
    }

    func testUnknownCategoryStringIsRecoveredInsteadOfDropped() throws {
        let task = FocusTask(title: "未来的任务", category: .study)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var array = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode([task])) as? [[String: Any]]
        )
        array[0]["category"] = "未来的分类"
        try JSONSerialization.data(withJSONObject: array)
            .write(to: tempDir.appendingPathComponent("tasks.json"))

        let store = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks.first?.category.name, "未来的分类")
        XCTAssertTrue(store.tasks.first?.category.isBuiltIn == false)
        XCTAssertEqual(store.customCategories.first?.name, "未来的分类")
    }

    func testCustomDefinitionRecoversWhenStateFileIsMissing() throws {
        let store = TaskStore(storageDirectory: tempDir)
        let category = try XCTUnwrap(success(
            store.addCustomCategory(name: "健身", colorHex: "#10B981", icon: "figure.run")
        ))
        store.newTaskTitle = "跑步 5 公里"
        store.newTaskCategory = category
        store.addTask(for: .todayTask)

        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("app_state.json"))

        let reloaded = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(reloaded.customCategories.first?.name, "健身")
        XCTAssertEqual(reloaded.customCategories.first?.id, category.id)
        XCTAssertEqual(reloaded.tasks.first?.category, category)

        let secondReload = TaskStore(storageDirectory: tempDir)
        XCTAssertEqual(secondReload.customCategories, [category])
    }

    private func success<T, E: Error>(_ result: Result<T, E>) -> T? {
        guard case .success(let value) = result else { return nil }
        return value
    }
}
