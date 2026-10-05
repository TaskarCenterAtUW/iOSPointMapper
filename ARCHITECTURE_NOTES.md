# Architecture Notes

## Main application

`IOSAccessAssessment` is the primary iOSPointMapper application target.

## PointNMap frameworks

Reusable mapping functionality lives in the separate PointNMap repository,
which must be checked out at:

```text
Frameworks/PointNMap
```

The main application references:
• Frameworks/PointNMap/PointNMap.xcodeproj
• PointNMapShared.framework
• PointNMapShaderTypes.framework
PointNMapShared contains the reusable Swift, Metal, computer-vision, and mapping functionality.
PointNMapShaderTypes contains C-compatible types shared by Swift and Metal code.
The former root-level PointNMapShared and PointNMapShaderTypes directories were obsolete copies and are not authoritative.

### Initial setup
Clone the PointNMap repository from the iOSPointMapper repository root:
```text
git clone git@github.com:himanshunaidu/PointNMap.git Frameworks/PointNMap
```
The PointNMap repository is managed independently and is ignored by the parent repository. Changes must be committed and pushed from inside Frameworks/PointNMap.

### Header configuration
The IOSAccessAssessment app target uses these header paths:
```bash

HEADER_SEARCH_PATHS:
$(SRCROOT)/IOSAccessAssessment
$(SRCROOT)/Frameworks/PointNMap/PointNMapShaderTypes

MTL_HEADER_SEARCH_PATHS:
$(SRCROOT)/IOSAccessAssessment
$(SRCROOT)/Frameworks/PointNMap/PointNMapShaderTypes

```
The application bridging header imports the public framework header:
```swift
#import <PointNMapShaderTypes/ShaderTypes.h>
```

Metal files that use ShaderTypes.h resolve it through MTL_HEADER_SEARCH_PATHS.

Unit-test and UI-test targets do not require copies of these header-search settings unless they directly compile C, Objective-C, or Metal sources.
If you use HTTPS instead of SSH, change the clone URL accordingly.



