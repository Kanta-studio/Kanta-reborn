*** Begin Patch
*** Update File: apps/ios/Tests/KantaUITests/KantaVisualWalkthroughUITests.swift
@@
     @MainActor
-    func testRestoredHostInlineRemoteAndLibrary() throws {
-        let app = XCUIApplication()
-        app.launchEnvironment["KANTA_DEMO_MODE"] = "0"
-        app.launch()
-        XCTAssertTrue(app.staticTexts["NOW SINGING"].waitForExistence(timeout: waitSeconds))
-        capture("restored-host-stage", app)
-        let panel = app.disclosureTriangles["host.remotePanel"]
-        let fallbackPanel = app.buttons["host.remotePanel"]
-        let remote = panel.exists ? panel : fallbackPanel
-        for _ in 0..<4 where !remote.isHittable { app.swipeUp() }
-        XCTAssertTrue(remote.isHittable)
-        capture("restored-host-remote-collapsed", app)
-        remote.tap()
-        XCTAssertTrue(app.textFields["Search song title or code"].waitForExistence(timeout: 5))
-        XCTAssertFalse(app.navigationBars["CONTROL"].exists, "Inline remote must not present a sheet")
-        XCTAssertTrue(app.buttons["stage.playPause"].exists, "Expansion must preserve the stage")
-        capture("restored-host-remote-expanded", app)
-        remote.tap()
-        for _ in 0..<4 where !app.buttons["More"].isHittable { app.swipeDown() }
-        openMenu(in: app, expecting: "Song Library")
-        app.buttons["Song Library"].tap()
-        XCTAssertTrue(app.buttons["library.addFolder"].waitForExistence(timeout: 5))
-        XCTAssertTrue(app.buttons["library.chooseFolder"].exists)
-        capture("restored-library-empty", app)
-    }
+    // Helper: wait until element is hittable or fail
+    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
+        let predicate = NSPredicate(format: "exists == true AND hittable == true")
+        let exp = expectation(for: predicate, evaluatedWith: element, handler: nil)
+        let result = XCTWaiter().wait(for: [exp], timeout: timeout)
+        return result == .completed
+    }
+
+    @MainActor
+    func testRestoredHostInlineRemoteAndLibrary() throws {
+        let app = XCUIApplication()
+        app.launchEnvironment["KANTA_DEMO_MODE"] = "0"
+        app.launch()
+
+        XCTAssertTrue(app.staticTexts["NOW SINGING"].waitForExistence(timeout: waitSeconds))
+        capture("restored-host-stage", app)
+
+        // Prefer accessibility identifier-based lookups to avoid fragile element-type queries.
+        let remotePanel = app.otherElements["host.remotePanel"]
+        // Fallback for legacy builds that might expose the panel as a button
+        let remoteElement = remotePanel.exists ? remotePanel : app.buttons["host.remotePanel"]
+
+        XCTAssertTrue(waitForHittable(remoteElement), "Remote panel must become hittable")
+        capture("restored-host-remote-collapsed", app)
+
+        remoteElement.tap()
+
+        XCTAssertTrue(app.textFields["Search song title or code"].waitForExistence(timeout: 5))
+        // Ensure CONTROL did not open as an overlay (inline expansion expected)
+        XCTAssertFalse(app.navigationBars["CONTROL"].exists, "Inline remote must not present a sheet")
+        XCTAssertTrue(app.buttons["stage.playPause"].waitForExistence(timeout: 3), "Stage controls must remain present")
+        capture("restored-host-remote-expanded", app)
+
+        // Collapse remote and navigate to the library
+        remoteElement.tap()
+        XCTAssertTrue(waitForHittable(app.buttons["More"], timeout: 6))
+        openMenu(in: app, expecting: "Song Library")
+        app.buttons["Song Library"].tap()
+
+        XCTAssertTrue(app.buttons["library.addFolder"].waitForExistence(timeout: 5))
+        XCTAssertTrue(app.buttons["library.chooseFolder"].exists)
+        capture("restored-library-empty", app)
+    }
*** End Patch