# Health to Obsidian - Xcode Setup Guide

## Creating the Xcode Project

1. Open Xcode and select **File > New > Project**
2. Choose **iOS > App** and click Next
3. Configure the project:
   - Product Name: `HealthToObsidian`
   - Organization Identifier: Your reverse domain (e.g., `com.yourname`)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests" (optional)
4. Click Next and choose where to save the project

## Adding the Source Files

1. In Xcode, delete the auto-generated `ContentView.swift` file
2. Right-click on the `HealthToObsidian` folder in the navigator
3. Select **Add Files to "HealthToObsidian"**
4. Navigate to this folder and select all `.swift` files:
   - `HealthToObsidianApp.swift`
   - `ContentView.swift`
   - `Models/HealthData.swift`
   - `Managers/HealthKitManager.swift`
   - `Managers/VaultManager.swift`
   - `Views/FolderPicker.swift`
5. Make sure "Copy items if needed" is checked
6. Click Add

## Configuring the Project

### Set Deployment Target
1. Select the project in the navigator (blue icon at top)
2. Select the `HealthToObsidian` target
3. Go to **General** tab
4. Set **Minimum Deployments** iOS version to `17.0`

### Add HealthKit Capability
1. Select the project in the navigator
2. Select the `HealthToObsidian` target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Search for and add **HealthKit**
6. In the HealthKit section that appears, check these clinical types if you want to access them (optional):
   - Background Delivery (not needed for this app)

### Configure Info.plist
1. Select `Info.plist` in the navigator (or access via target's Info tab)
2. Add a new row:
   - Key: `NSHealthShareUsageDescription`
   - Type: String
   - Value: `This app reads your health data to export it to your Obsidian vault.`

Alternatively, you can replace the auto-generated Info.plist with the provided `Info.plist` file.

## Project Structure

After setup, your project should look like this:

```
HealthToObsidian/
├── HealthToObsidianApp.swift    # App entry point
├── ContentView.swift             # Main UI
├── Models/
│   └── HealthData.swift          # Data models & markdown export
├── Managers/
│   ├── HealthKitManager.swift    # HealthKit data fetching
│   └── VaultManager.swift        # File export & bookmarks
└── Views/
    └── FolderPicker.swift        # Folder selection UI
```

## Building and Running

1. Connect an iPhone (iOS 17+) or select a simulator
   - **Note:** HealthKit only works on a real device, not the simulator
2. Select your device as the run destination
3. Press **Cmd+R** to build and run
4. On first launch, the app will request access to your health data

## Testing

### On Simulator (Limited)
- You can test the UI and folder selection
- HealthKit data will return empty results

### On Device (Full Functionality)
1. Grant health permissions when prompted
2. Select your Obsidian vault folder (must be accessible via Files app)
3. Choose a date with health data
4. Tap Export
5. Open Obsidian and verify the markdown file was created

## Troubleshooting

### "Health data not available"
- You're running on the simulator. Use a real device.

### "Cannot access the vault folder"
- The bookmark may have become invalid. Re-select the vault folder.

### No data exported
- Check that you have health data for the selected date
- Verify all health permissions were granted in Settings > Privacy > Health

### Build errors
- Ensure deployment target is iOS 17.0+
- Verify HealthKit capability is added
- Check that all source files are included in the target
