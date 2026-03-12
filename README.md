# Cashflow

Fresh SwiftUI starter app.

## Run

1. Generate the project:
   ```sh
   xcodegen generate
   ```
2. Open `Cashflow.xcodeproj` in Xcode.
3. Run on an iPhone simulator (`Cmd + R`).

## Simulator Fullscreen Troubleshooting

If the Simulator shows the app as a letterboxed/inset card (not full device viewport),
use this checklist.

### Required project settings

The iOS target must keep these plist properties in `project.yml` under:
`targets -> Cashflow -> info -> properties`

- `UILaunchStoryboardName: LaunchScreen`
- `UIRequiresFullScreen: true`
- `UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]`

Also keep `Sources/App/LaunchScreen.storyboard` in the project.

After editing `project.yml`, always regenerate:

```sh
xcodegen generate
```

### Reset simulator/app state

1. Delete the app from Simulator.
2. In Xcode: `Shift + Cmd + K` (Clean Build Folder).
3. Run again (`Cmd + R`).

If needed, reset simulator services:

```sh
xcrun simctl shutdown all
xcrun simctl erase all
```
