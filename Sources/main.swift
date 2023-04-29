import Foundation
import AppKit

// Execute shell command
func shell(_ command: String, _ args: String...) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = args

    let outputPipe = Pipe()
    process.standardOutput = outputPipe

    do {
        try process.run()
    } catch {
        print("Error: \(error.localizedDescription)")
    }

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: outputData, encoding: .utf8) ?? ""

    return output
}

// Get all commit hashes
func getAllCommits() -> [String] {
    let output = shell("/usr/bin/git", "log", "--pretty=format:%H")
    return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
}

// Get changed files for a specific commit
func getChangedFiles(for commit: String) -> [String] {
    let output = shell("/usr/bin/git", "diff-tree", "--no-commit-id", "--name-only", "-r", commit)
    return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
}

// Analyze commits and group files
func analyzeCommits(commits: [String]) -> [Set<String>] {
    var fileGroups: [Set<String>] = []

    for commit in commits {
        let changedFiles = Set(getChangedFiles(for: commit))
        if !changedFiles.isEmpty {
            var merged = false
            for (index, group) in fileGroups.enumerated() {
                if group.intersection(changedFiles).count > 0 {
                    fileGroups[index] = group.union(changedFiles)
                    merged = true
                    break
                }
            }
            if !merged {
                fileGroups.append(changedFiles)
            }
        }
    }

    return fileGroups
}

func drawGraph(fileGroups: [Set<String>]) {
    let width: CGFloat = 800
    let height: CGFloat = 600
    let margin: CGFloat = 20
    let backgroundColor = NSColor.white
    let groupColors = [NSColor.red, NSColor.green, NSColor.blue, NSColor.orange, NSColor.purple]

    let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect -> Bool in
        backgroundColor.set()
        rect.fill()

        let groupSize = NSSize(width: (width - 2 * margin) / CGFloat(fileGroups.count), height: height - 2 * margin)
        let groupRect = NSRect(origin: NSPoint(x: margin, y: margin), size: groupSize)

        for (index, _) in fileGroups.enumerated() {
            let color = groupColors[index % groupColors.count]
            color.set()

            let groupFrame = groupRect.offsetBy(dx: CGFloat(index) * groupSize.width, dy: 0)
            NSBezierPath(rect: groupFrame).fill()

            let groupName = "Group \(index + 1)"
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.black,
                .font: NSFont.systemFont(ofSize: 14)
            ]
            let groupNameSize = groupName.size(withAttributes: attrs)
            let groupNamePoint = NSPoint(x: groupFrame.midX - groupNameSize.width / 2, y: groupFrame.maxY - groupNameSize.height)
            groupName.draw(at: groupNamePoint, withAttributes: attrs)
        }

        return true
    }

    let outputURL = URL(fileURLWithPath: "graph.png")
    let imageRep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let pngData = imageRep.representation(using: .png, properties: [:])
    try! pngData?.write(to: outputURL)
}

// Main code
let commits = getAllCommits()
let fileGroups = analyzeCommits(commits: commits)

// Print the file groups
for (index, group) in fileGroups.enumerated() {
    print("Group \(index + 1):")
    for file in group {
        print("\t\(file)")
    }
}

// Draw the graph
drawGraph(fileGroups: fileGroups)
