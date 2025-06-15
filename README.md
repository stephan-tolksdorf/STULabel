
[![CircleCI](https://circleci.com/gh/stephan-tolksdorf/STULabel.svg?style=svg)](https://circleci.com/gh/stephan-tolksdorf/STULabel)
[![TravisCI](https://travis-ci.com/stephan-tolksdorf/STULabel.svg?branch=master)](https://travis-ci.com/stephan-tolksdorf/STULabel)
[![Swift 4.2](https://img.shields.io/badge/Swift-4.2-orange.svg?style=flat)](https://swift.org)
[![Version](https://img.shields.io/cocoapods/v/STULabelSwift.svg?style=flat)](http://cocoapods.org/pods/STULabelSwift)
![Platform](https://img.shields.io/cocoapods/p/STULabelSwift.svg?style=flat)
[![License](https://img.shields.io/cocoapods/l/STULabelSwift.svg?style=flat)](https://github.com/stephan-tolksdorf/STULabel/blob/master/LICENSE.txt)
[![Twitter](https://img.shields.io/badge/twitter-@s_tolksdorf-blue.svg)](http://twitter.com/s_tolksdorf)


STULabel is an open source iOS framework for Swift and Objective-C that provides a label view (`STULabel`), a label layer (`STULabelLayer`) and a flexible API for thread-safe text layout and rendering  (`STUShapedString`, `STUTextFrame`). The framework is implemented in Objective-C++ on top of the lower-level parts of the Core Text API. STULabel has a Swift overlay framework (STULabelSwift) that provides a convenient Swift API.

##### Table of Contents
- [Features](#stulabel-features)
- [Status](#status)
- [License](#license)
- [Integration](#integration)
- [Support](#support)
- [Some features in detail](#some-features-in-detail)
- [Limitations and differences compared to UILabel and UITextView](#limitations-and-differences-compared-to-UILabel-and-UITextView)

## STULabel features

- Faster than `UILabel` and `UITextView`
- Optional asynchronous layout and rendering
- Support for prerendering (useful e.g. in a collection view prefetch handler)
- Automatic switching to efficient tiled rendering for very large labels
- Text highlighting with color or decorations that doesn't require a text relayout
- Fast auto scaling of text ("shrink to fit size")
- Interactive hyperlinks with full  `UIDragInteraction` support
- Very flexible text truncation, including support for truncation tokens with embedded links and for multiple vertically stacked truncation scopes
- Auto Layout support
- Dynamic Type support
- UIAccessibility support
- Comprehensive support for right-to-left text
- Configurable vertical alignment and content insets
- Fine control over text layout, including support for fixed baseline distances and first baseline offsets
- Customizable automatic hyphenation
- Text attachments (inline images)
- Underlines with accurate descender gaps
- Flexible background decorations, e.g. with rounded corners
- Rich text layout information that is easy to query

The source code contains a demo app that you can build with the included Xcode project. The demo app contains:
- A viewer for the Universal Declaration of Human Rights that lets you view the document in languages with 39 different scripts (writing systems). You can experiment with fonts, spacings, text decorations, links, truncations, etc. and compare the text rendered by `STULabel`  with the text rendered by `UITextView`. 
- A `UITableView` scrolling stress test that lets you compare the performance of `STULabel`, `UILabel` and  `UITextView` and observe the effect of enabling or disabling Auto Layout, async rendering or prefetch layout/rendering.
- A micro benchmark that lets you measure and compare the layout and render performance of `STULabel`, `UILabel` and  `UITextView` for various test cases.
- A micro benchmark that lets you measure and compare the layout and render performance of `STUTextFrame`, `NSStringDrawing` and Text Kit for various  test cases.
- A view that implements a "tap to read more" feature with `STULabel`.

## Status

STULabel is pre-release ("beta") software. It has bugs, it needs more tests and it needs more documentation, yet it might already be good enough for your purposes. If you want to use it for anything serious, please subscribe to the bug tracker and update frequently.

The API and behaviour should be mostly stable now before the 1.0 release.  (*Binary* interface (ABI) stability is an explicit non-goal of this open source library.)

## License

Except where noted otherwise, everything in this repository is distributed under the terms of the 2-clause BSD license in [LICENSE.txt](LICENSE.txt).

The STULabel library incorporates data derived from the Unicode Character Database, which is distributed under the [Unicode, Inc. License Agreement](http://www.unicode.org/copyright.html#License).

## Integration

### CocoaPods integration

If you want to use STULabel from Objective-C code, add the following to your Podfile:
```
pod 'STULabel', '~> 0.8.12'
```

If you want to use STULabel from Swift code, add the following to your Podfile:
```
pod 'STULabelSwift', '~> 0.8.12'
```

STULabel is a dependency of STULabelSwift.

### Manual integration

- The STULabel project contains separate schemes for building STULabel and STULabelSwift both as dynamic and as static frameworks. 
- You should only link STULabelSwift  if you want to use STULabel from Swift code.
- If you want to use the static framework(s), you need to manually add the  `STULabelResources.bundle` product to your app or framework target. (The resources bundle contains the localized strings for the default link action sheets.)
- One way to manually integrate STULabel into your Xcode project is as follows:
  1. Close the STULabel project in Xcode if it is open.
  2. Open your project in Xcode if it isn't already open.
  3. Drag the STULabel project from Finder into the project navigator pane of the Xcode window of your project.
  4. Reveal the subtree below `STULabel.xcodeproj` in the project navigator and reveal the items in the `Products` group. You should now see two `STULabel.framework` items, two `STULabelSwift.framework` items, a `STULabelResources.bundle` and some other items. The identically named framework items are the dynamic and static builds of the respective frameworks. You can identify the static frameworks by their full paths in the Xcode file inspector (in the right Xcode pane). For example, the full path of the static `STULabel.framework` ends with ' `-static/STULabel.framework`'. 
  5. Select your project at the top of the Xcode project navigator pane.
  6. Select your app or framework target in the center view (the standard editor view in the middle of the window).
  7. Select the 'General' tab in the center view.
  8. If you want to use the dynamic framework(s):
      * Drag the *non-static* `STULabel.framework` from the `Products` group of  the `STULabel.xcodeproj` in the project navigator pane to the 'Embedded Binaries' section in the center view. When you drop it there, the framework will also be added below below in the 'Linked Frameworks and Libraries' list.
      * Do the same with the  *non-static* `STULabelSwift.framework` if you want to use Swift.
    
      If you want to use the static framework(s) instead:
      * Add the following items to the 'Linked Frameworks and Libraries' section, e.g. by clicking on the '+' button and selecting the respective items:
        - `STULabel.framework` from the static target,
        - `STULabelSwift.framework` from the static target, if you want to use Swift,
        - `libc++.tbd`, unless that library was already added before.
      * Select the 'Build Phases' tab in the center view.
      * Add the static `STULabel(Swift)` framework(s) that you just added to the list of linked frameworks also to the list of 'Target dependencies'. 
      * Add `STULabelResources` to the 'Target dependencies'.
      * Reveal the 'Copy Bundle Resources' section.
      * Drag the `STULabelResources.bundle` from the `Products` group of the `STULabel.xcodeproj` to the 'Copy Bundle Resources' section.
      * Select the 'Build Settings' tab in the center view.
      * Add `$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)-static` to the 'Framework Search Paths'.

### LLDB formatters

The STULabel source contains an [LLDB Python script](STULabel/stu_label_lldb_formatters.py) that defines data formatters for various types defined by the library. If you find yourself stepping through STULabel code in Xcode, importing this script will improve your debugging experience.
  
## Support

If you've found a bug, please create a GitHub issue. If possible, please provide sample code that reproduces the issue.

If you have a question regarding the use of STULabel, e.g. how to accomplish a certain text layout, please ask the question on Stack Overflow and tag it with 'STULabel'.

## Some features in detail

### Performance

Synchronous layout and rendering with `STULabel` is faster than `UILabel` and `UITextView`, sometimes *several times* faster. How much faster `STULabel` is depends both on the specific use case and on the device and iOS version. The Demo app contains a micro benchmark for label views that lets you compare the performance of `STULabel`, `UILabel` and `UITextView` for various test cases on your own devices.

`STULabel` is faster than `UILabel` mainly because it caches text layout data more aggressively. In part this is due to `UILabel` using `NSStringDrawing` for layout and rendering purposes, which doesn't support persisting the calculated text layout, while `STULabel` is using the `STUTextFrame` API (implemented on top of Core Text's `CTTypesetter`), which makes it very easy to separate the text shaping and layout from the text rendering.

`UITextView` seems to be primarily designed for lazily typesetting large mutable texts and supporting fine-grained customization of the layout process, not for displaying smallish static strings.

The automatic text scaling implementation in `STULabel` is particularly fast because instead of scaling down the font sizes it scales up the layout width and then scales down content during drawing. This has the advantage that the attributed string doesn't have to be recreated, font object caches are less loaded and most of the text shaping only has to be done once. The Core Graphics render quality on iOS should be equal for both approaches.

### Async rendering

Text layout and rendering can constitute a large part of the total time that the main thread spends on layout and rendering, particularly if the text is written in languages using complex scripts, like e.g. Hindi or Arabic. The asynchronous layout and rendering support in `STULabel` makes it easy to move at least part of this work to a background thread. (Image decoding and drawing can be another main-thread performance bottleneck on iOS, but that is usually much simpler to move to a background thread than text layout and rendering).

The `UITableView` example in the Demo app lets you enable or disable async and prefetch rendering for the `STULabel` views and thus allows you to observe the effect that these features can have on scrolling performance. (If you're using a fast device, you may have to increase the auto scroll speed to make the difference obvious.)

You can enable asynchronous rendering for `STULabel` views simply by setting the `displaysAsynchronously` property to true. 

Doing the full text layout asynchronously is a bit more complicated, since you'll have to do it e.g. in a collection view prefetch handler and you need to know all the relevant layout parameters in advance in order to configure the [`STULabelPrerenderer`](STULabel/STULabelPrerenderer.h) object. 

However, often you don't need to do the full layout on a background thread to achieve absolutely smooth scrolling with 60 or 120 FPS. Doing just the text shaping in advance, by constructing `STUShapedString` instances for the attributed strings that you want to display, and then configuring the label views the with the shaped strings instead of the attributed strings will already improve layout performance considerably.

In certain situation asynchronous rendering can be detrimental to the user experience, e.g. when it leads to visible flickering or breaks animations. `STULabel` will automatically switch to synchronous rendering when it can easily detect such a situation, e.g. when the layout was initiated in a `UIView` animation block. When this automatic behaviour isn't sufficient, you can e.g. temporarily disable async rendering through the delegate interface.

### Flexible text truncation

- STULabel lets you specify the attributed string that should be used as the truncation token. This way you can e.g. use "……" for ellipsizing Chinese text. Or you can implement a 'tap to read more' feature by setting the string `"… more"` with a link attribute as the truncation token and then setting `maximumNumberOfLines` to 0 when the link is tapped.

- STULabel lets you customize the possible truncation points in the text. If you e.g. want to prevent truncations in the middle of certain words or after whitespace, you can do so by setting a `truncationRangeAdjuster` function that doesn't accept such positions.

- STULabel lets you specify multiple truncation scopes within the same attributed string. This way you can display multiple paragraphs of text in the same label that you otherwise might have to split into multiple labels, which simplifies your layout code and improves performance. 

  For example, you can display the full text of a Twitter message in a single `STULabel` by designating the first line of text with the user name as a separate truncation scope, so that the user name gets truncated if necessary, but the timestamp and the following paragraphs are left intact. The `UITableView` in the Demo app does exactly this for the "Social media" test cases.

## Limitations and differences compared to UILabel and UITextView

### No Interface Builder support

Xcode's Interface Builder doesn't support `UIFont`, `NSAttributedString`, `UIEdgeInsets` or any enum type as the type of an `IBInspectable` property, so there's currently no way to make `STULabel`  work in IB like `UILabel` or `UITextView`.
 
If you can live with the  `IBInspectable` limitations, e.g. because your application only uses a fixed set of "styles", you can of course subclass `STULabel` and make the subclass `IBDesignable` .

### Auto Layout support

The Auto Layout support for `UILabel` and `UITextView`  in UIKit makes extensive use of private APIs. Consequently, the Auto Layout support in STULabel has certain limitations: 

- Auto Layout does not natively support views whose intrinsic content height depends (non-linearly) on the layout width. In order to support multi-line text views in Auto Layout, UIKit has a private API that allows `UILabel` and `UITextView` to opt into a special two-pass layout process. In complex situations the results of this undocumented two-pass layout are sometimes unsatisfying.

  Since `STULabel` cannot take part in the two-pass layout, it uses a different approach: It calculates the **intrinsic content size** by calculating the size of the text both for an unlimited width and for the current view width and then taking the maximum width and height from both sizes. When the view width changes, the intrinsic content size is marked as invalidated and the UIKit layout algorithm is forced to update the layout for the changed intrinsic content size. This approach seems to work reliably even in complex situations.

- The `UIView.systemLayoutsSizeFitting(...)` methods calculate a view's size purely based on the subview constraints. They don't call any `layoutSubviews` method and hence generally can't determine the correct view size if any view in the subview hierarchy depends on manual layout code. Since `STULabel`'s Auto Layout support depends on a full UIKit layout pass, including calls to `layoutSubviews`,   `systemLayoutsSizeFitting` will not calculate the correct size for a view that contains a multi-line `STULabel` subview, unless the label already has the correct width.  ( `UILabel` and `UITextView` don't have this problem because they get the special two-pass layout treatment mentioned before.) 
  
    If you call `systemLayoutsSizeFitting` in your own code, you can probably replace it with a `layoutIfNeeded` call on the superview (if necessary, by temporarily adding the view as a child to a superview).
    
   `UITableView`  and `UICollectionView` use `systemLayoutsSizeFitting` for self-sizing cells. A simple way to make this work for cells containing `STULabel` views is to subclass `UITableViewCell`/ `UICollectionViewCell` and override `systemLayoutSizeFitting` as follows:
     ```
     public override 
     func systemLayoutSizeFitting(_ targetSize: CGSize,
            withHorizontalFittingPriority hp: UILayoutPriority,
            verticalFittingPriority vp: UILayoutPriority) -> CGSize
    {
      self.layoutIfNeeded()
      return super.systemLayoutSizeFitting(targetSize, 
                     withHorizontalFittingPriority: hp,
                     verticalFittingPriority: vp)
    }
    ```

    The `layoutIfNeeded()`  call ensures that all labels already have the correct width when `systemLayoutSizeFitting` is called. (When `UITableView` calls this method, the cell's width already matches `targetSize.width`. If it didn't, you could just [adjust the cell's bounds before calling `self.layoutIfNeeded`](Demo/AutoHeightTableViewCell.swift).)
  
- Returning a `STULabel` from an `viewForFirstBaselineLayout` or `viewForFirstBaselineLayout` property will not have the desired effect due to UIKit private API limitations. However, if you override `firstBaselineAnchor` and `lastBaselineAnchor` instead and pass on the respective anchors from the label subview, baseline constraints should work as expected.
  
- The system spacing contraints introduced in iOS 11 that you can create e.g. with `constraint(equalToSystemSpacingBelow:multiplier:)` will not work properly with `STULabel` views, because they rely on private UIKit APIs. (The exact behaviour of these constraints is undocumented. The iOS 12 implementation calculates a spacing that depends only on the font of the first character of any involved label. Any other font and any paragraph style is ignored.)
  
  As a replacement for the vertical system spacing constraints, STULabel provides `NSLayoutYAxisAnchor` extension methods that allow you to create constraints relative to the exact line heights of the involved `STULabel` views, see [`NSLayoutAnchor+STULabelSpacing.overlay.swift`](STULabelSwift/NSLayoutAnchor+STULabelSpacing.overlay.swift) or [`NSLayoutAnchor+STULabelSpacing.h`](STULabel/NSLayoutAnchor+STULabelSpacing.h).
  
- On iOS 9 creating a baseline constraint directly with `NSLayoutConstraint.init` will not work properly if it involves a `STULabel` view. You can work around this limitation by creating the constraint with the help of a layout anchor instead. iOS 10 and later iOS versions don't have this issue because the `NSLayoutConstraint` initializer automatically fetches the respective layout anchors.
  
### Line height

- `UILabel` ignores the font `leading` ('line gap') property when computing the line height and spacing, while `UITextView` and `STULabel` do not. This will lead to differences in the default line height and layout bounds if a font has a positive `leading`. 

  Unless compensated by e.g. an appropriate `lineSpacing` paragraph style property, ignoring a positive leading will generally lead to inadequate line spacing, especially when typesetting e.g. Arabic or Thai text. Note that while the default label font and the fonts returned by `UIFont.systemFont` have a zero leading, the fonts returned by `UIFont.preferredFont` usually have a positive leading. (Some preferred fonts also have a *negative* leading, like e.g. the 'caption2' style fonts for size categories ≤ 'large', but STULabel currently ignores negative leadings.)

- `UILabel` and `UITextView` calculate the line height only based on the typographic metrics of the original fonts, while `STULabel` in the default text layout mode will also take into account the metrics of fallback fonts that were substituted for the original fonts during typesetting. 

  Unless compensated through the paragraph style, ignoring the metrics of the substituted fonts will generally lead to inadequate line heights when typesetting e.g. Asian language texts using the system font. If you prefer the Text Kit behaviour anyway, you can set the `STULabel.textLayoutMode` to `.textKit`.
  
  (The current Text Kit behaviour is probably the reason why the ascent and descent metrics of the fonts returned by `UIFont.preferredFont` depend on the application locale and are e.g. larger in the Thai locale even when only displaying English text.)

- The `STULabel.textLayoutMode` also affects the exact line height and baseline placement in other ways, as described in the documentation for `STUTextLayoutMode`. If you prefer the Text Kit behaviour, set the `textLayoutMode` to `.textKit`.

- If a `UILabel` only has a single line, the paragraph style's line spacing is added to the bottom of the content. If the label has more than a single line, it doesn't add any line spacing after the last line. `STULabel` and `UITextView` don't imitate this inconsistency and never add any paragraph style line spacing after the last line.

### Display scale rounding

When Core Graphics draws non-emoji glyphs into a bitmap context, it will round up the vertical glyph position (assuming an upper-left origin) such that the baseline Y-coordinate falls on a pixel boundary, except if the text is rotated or the context has been configured to allow vertical subpixel positioning by explicitly setting both `setShouldSubpixelPositionFonts(true)` and `setShouldSubpixelQuantizeFonts(false)`. (The precise font rendering behaviour of Core Graphics and Core Text is completely undocumented and there are no public API functions for reading the current configuration of a `CGContext`.)

`UILabel`, `UITextView` and `STULabel` all first calculate the text layout ignoring any display scale rounding.

When `UILabel` draws text, it adjusts the origin of the drawn text rectangle such that the Y-coordinate of the last baseline is rounded to the nearest pixel boundary. Thus, the exact position of the first baseline depends on the position of the last baseline.

`UITextView` and `STULabel` don't adjust the vertical text position like `UILabel` does.

`UITextView` leaves the baseline display scale rounding to Core Graphics.

`STULabel` anticipates the display scale rounding by Core Graphics. When it draws a line of text it adjusts the text matrix of the Core Graphics context such that the baseline falls on the next pixel boundary. This approach has the advantage that the rendered emoji and non-emoji glyphs always have the correct relative vertical alignment.

Probably due to these display scale rounding issues, the intrinsic content height or `sizeThatFits` of a `UILabel` or `UITextView` can in certain situations be  1 pixel too short. Similarly, the vertical position of an `UILabel` or `UITextView` baseline anchor can be off by 1 pixel. `STULabel` doesn't have these issues.

### Alignment and layout bounds

- `UILabel` always displays the content vertically centered within its bounds, while `UITextView` always uses top-aligmnent. `STULabel` lets you chose between top, bottom and 3 types of vertical center alignments (centered around the midpoint of the layout bounds, the x-height bounds or the cap-height bounds).

- `UITextView`  and `STULabel` both have customizable content insets, i.e. padding around the text. The `UITextView.textContainerInset` is non-zero by default, while  the `STULabel.contentInsets` are zero by default. 

  `STULabel` also supports setting the insets based on the UI layout direction (via the `STULabel.directionalContentInsets`) and exposes a `UILayoutGuide` that is pinned to bounds of the label without the insets (`STULabel.contentLayoutGuide`).

  `UILabel` does not have built-in support for content insets. It is possible to subclass `UILabel` and override `UILabel.textRect(forBounds:limitedToNumberOfLines:)` in order to implement such insets, but this can break e.g. parts of the Auto Layout support, particularly for attributed strings.

- Content insets can be important for ensuring that diacritics or other text features that exceed the typographic layout bounds do not get clipped during the rendering. Since `UILabel` doesn't have insets, it uses a different approach: When it displays text, it calculates outsets for the text that depend on the text content and the used fonts. These outsets are usually conservative and appear to be based on whether the text contains code points from certain Unicode ranges. If the layout bounds plus the calculated outsets do not fit the label view bounds and the view's `clipsToBounds` property is false (the default), the text is displayed in a sublayer whose frame exceeds the labels bounds. If it wasn't for this feature, e.g. Arabic or Thai text using the system font would regularly get clipped when being displayed in a `UILabel` view.

  Even though  `STULabel` does support insets, it doesn't rely on the insets for ensuring that diacritics and text decorations do not get clipped. Like `UILabel` it will switch to displaying the text in a sublayer if necessary (unless `clipsContentToBounds` is set to `true`). However, in contrast to `UILabel`, `STULabel` uses the exact image bounds of the rendered text, not some inaccurate estimates, to determine whether it needs to use a sublayer. This only costs a few percent performance overhead because `STULabel` uses a very fast custom glyph bounds cache.

### Line breaking and truncation

- The line breaks that `STULabel` chooses for a given layout width and font size may slightly differ from those chosen by `UILabel` and `UITextView`, particularly for complex scripts.

- The `STULabel.sizeThatFits(_ maxSize:)` method will calculate the size that fits the specified size, even if it means truncating or scaling the text, as specified by the  truncation and scaling settings. If you want a size that doesn't involve truncation, pass a sufficiently large maximum size. This behaviour differs from the behaviour of `UILabel` and `UITextView`.

-  `STULabel`, `UILabel` and `UITextView` all handle a `NSParagraphStyle.lineBreakMode`  that is not equal to `byWordWrapping` differently. The `STULabel` behaviour is hopefully consistent and intuitive.

- In contrast to `UILabel` and `UITextView`,  `STULabel` doesn't allow "head" or "middle" truncation of the first paragraph in a multiple-paragraph truncation, because that could mislead the reader as to which part of the text was truncated. It will automatically switch to "tail" truncation instead. Similarly,  `STULabel` will *not* omit the truncation token after a paragraph if the paragraph itself fully fits but not a single line of the following text.

- `STULabel` does not support `NSLineBreakMode.byClipping` at the paragraph level,  but you can specify `.clip` as the `STULabel.lastLineTruncationMode` to allow clipping at the end of a label.

- `STULabel` does not support "text tightening", i.e. negative kerning, as an alternative to truncation, like `UILabel` does through the `allowsDefaultTighteningForTruncation` and `NSParagraphStyle.allowsDefaultTighteningForTruncation` properties.
  
  If you want to avoid truncation, consider allowing the text to scale by specifiying a `minimumTextScaleFactor` less than 1.
  
### Text attributes and decorations

- If you set an attributed string that contains text ranges without a font property to the `attributedText` or `shapedText` property of a  `STULabel`, the Core Text default font (Helvetica 12pt) will be used for those text ranges. Since that is probably not the font that you want, you should make sure that all ranges in the attributed string have an explicitly specified font. `UILabel` and `UITextView` use `UIFont.systemFont(size: 17)` as the default font in that situation.

- `STULabel` will generally draw text decorations slightly different from `UILabel` and `UITextView`. For example, the
underline thickness is calculated based both on the original font and the substituted font (which leads to a more consistent thickness) and the descender gaps are more accurate. 

- `STULabel` does not support  `NSUnderlineStyle.byWord`. 

- `STULabel` does not support  the `.obliqueness`, `.expansion` and `.textEffect` string attributes. Instead of using these attributes, you could use a different font (possibly one with a nonstandard font matrix).

- `STULabel` does not support `NSTextBlock`, `NSTextList`,  `NSTextTable` and other Text Kit attributes.

### Links

- `STULabel` has no built-in support for automatically detecting URLs, telephone numbers, etc. like `UITextView` does through the `dataDetectorTypes` property. 
  
   Instead of letting the label detect the links, you could implement a helper function that uses `NSDataDetector` to find the relevant text ranges and construct an attributed string containing the appropriate links. Doing it this way makes it obvious in your code when this potentially expensive operation runs and simplifies moving the work into a background thread.
   
-  `STULabel` has no built-in support for 3D touch or "Peek and Pop" link preview.

- The way links embedded in the text are announced by Voice Over and the way links are navigable via Voice Over differ between `STULabel`,  `UILabel`  and `UITextView` and depend on the iOS version. Some of the relevant `UIAccessibility` API is private, which complicates the support in `STULabel`.

### Other limitations

- `STULabel` currently does not support text selection.  (The infrastructure for mapping points to characters already exists, but the selection logic, gesture recognition, etc. still needs to be implemented.)

- `STULabel` and `STUTextFrame` don't support specifying an exclusion path, in contrast to  `UITextView` and `NSTextContainer`.

  In some situations, horizontal paragraph indentations may be a sufficient alternative to a general exclusion path. `STUParagraphStyle` lets you specify the number of lines in a paragraph to which the `initialLinesHeadIndent` and a `initialLinesTailIndent` apply (similar to what you can do with Android's [`LeadingMarginSpan2`](https://developer.android.com/reference/android/text/style/LeadingMarginSpan.LeadingMarginSpan2)), which make the indentations a little more flexible than in `UILabel` and `UITextView`.

- STULabel does not support vertical text.

(This list is not complete.)



