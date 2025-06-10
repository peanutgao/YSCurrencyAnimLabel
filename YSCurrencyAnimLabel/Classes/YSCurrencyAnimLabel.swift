//
//  YSCurrencyAnimLabel.swift
//  YSCurrencyAnimLabel
//
//  Created by Joseph on 2025/6/5.
//

import UIKit

// MARK: - Vertical Alignment

/// Vertical alignment options for the currency animation label
public enum YSVerticalAlignment {
    case top
    case center
    case bottom
}

// MARK: - YSCurrencyAnimLabel

public class YSCurrencyAnimLabel: UILabel {
    public var isCurrency = true
    public var isShowSymbol = false
    public var currSymbol: String = "$" {
        didSet {
            refreshDisplayWithoutAnimation()
        }
    }
    public var numberFormatter: NumberFormatter = .init() {
        didSet {
            if prevNumber != 0, !areFormattersEqual(oldValue, numberFormatter) {
                refreshDisplayWithoutAnimation()
            }
        }
    }

    /// Vertical alignment for the text content
    public var verticalAlignment: YSVerticalAlignment = .center {
        didSet {
            if oldValue != verticalAlignment {
                updatePositionsOnly()
            }
        }
    }

    /// Whether to show animation for all digit positions even if their values haven't changed
    /// When set to true, if any digit changes, all digit positions will show scroll animation
    /// When set to false, only digits that actually changed will show animation
    public var animateAllWhenChanged = false

    public private(set) var fullText = ""

    private var amountColor: UIColor = .black
    private var scrollLayers: [CAScrollLayer] = []
    private var scrollLabels: [UILabel] = []
    private let duration = 0.7
    private let durOffset = 0.2
    private let nonAnimTexts = [",", "."]

    /// Store the previous number for comparison
    private var prevNumber: Int64 = 0

    // swiftlint:disable:next implicitly_unwrapped_optional
    override public var textColor: UIColor! {
        get {
            amountColor
        }
        set {
            super.textColor = .clear
            amountColor = newValue
        }
    }

    public func setNumber(_ num: Int64) {
        if isCurrency {
            fullText = currencyString(from: num)
        } else {
            fullText = String(num)
        }

        text = getText()
        updateSubviews(prevNum: prevNumber, currNum: num)
        animate()
        prevNumber = num
    }

    /// Convenience method to set currency symbol and enable symbol display
    public func setCurrency(symbol: String) {
        currSymbol = symbol
        isShowSymbol = true
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        textColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        if !subviews.filter({ $0.tag != 8898 }).isEmpty || !scrollLayers.isEmpty {
            updatePositionsOnly()
        }
    }
    func refreshDisplayWithoutAnimation() {
        guard prevNumber != 0 else {
            clean()
            return
        }

        if isCurrency {
            fullText = currencyString(from: prevNumber)
        } else {
            fullText = String(prevNumber)
        }

        text = getText()

        clean()

        guard !fullText.isEmpty else { return }

        // Recreate display content without animation
        let strArray = fullText.map { String($0) }
        var xPos: CGFloat = 0
        let frameW = bounds.size.width
        let textW = textWidth()

        let textHeight = getTextHeight()
        let yPos = calculateVerticalPosition(for: textHeight)

        if textAlignment == .center {
            xPos = (frameW - textW) / 2
        } else if textAlignment == .right {
            xPos = frameW - textW
        }

        if isShowSymbol {
            let symbolLabel = createScrollLabel(text: "\(currSymbol) ", origin: CGPoint(x: xPos, y: yPos))
            addSubview(symbolLabel)
            xPos += symbolLabel.bounds.width
        }

        // Create static labels without animation
        for text in strArray {
            let label = createScrollLabel(text: text, origin: CGPoint(x: xPos, y: yPos))
            addSubview(label)
            xPos += floor(label.bounds.width)
        }
    }

    /// Compare if two NumberFormatter instances have the same formatting settings
    /// Used to avoid unnecessary re-formatting
    func areFormattersEqual(_ formatter1: NumberFormatter, _ formatter2: NumberFormatter) -> Bool {
        formatter1.numberStyle == formatter2.numberStyle &&
            formatter1.groupingSeparator == formatter2.groupingSeparator &&
            formatter1.decimalSeparator == formatter2.decimalSeparator &&
            formatter1.minimumFractionDigits == formatter2.minimumFractionDigits &&
            formatter1.maximumFractionDigits == formatter2.maximumFractionDigits &&
            formatter1.minimumIntegerDigits == formatter2.minimumIntegerDigits &&
            formatter1.usesGroupingSeparator == formatter2.usesGroupingSeparator &&
            formatter1.locale == formatter2.locale
    }
}

private extension YSCurrencyAnimLabel {
    enum AnimationType {
        case none // No animation (identical digits or separators)
        case scroll // Scroll animation (0-9-0 effect for unchanged digits)
        case change // Change animation (digits that actually changed)
    }

    func updateSubviews(prevNum: Int64 = 0, currNum: Int64) {
        clean()

        layoutIfNeeded()
        let strArray = fullText.map { String($0) }
        var xPos: CGFloat = 0
        let frameW = bounds.size.width
        let textW = textWidth() // getTextSize(for: getText(), with: font).width

        let textHeight = getTextHeight()
        let yPos = calculateVerticalPosition(for: textHeight)

        if textAlignment == .center {
            xPos = (frameW - textW) / 2

        } else if textAlignment == .right {
            xPos = frameW - textW
        }

        if isShowSymbol {
            let symbolLabel = createScrollLabel(text: "\(currSymbol) ", origin: CGPoint(x: xPos, y: yPos))
            addSubview(symbolLabel)
            xPos += symbolLabel.bounds.width
        }

        let animFlags = calculateAnimationFlags(
            strArray: strArray,
            prevNum: prevNum,
            currNum: currNum
        )

        for (index, text) in strArray.enumerated() {
            let label = createScrollLabel(text: text, origin: CGPoint(x: xPos, y: yPos))

            let animType = animFlags[index]

            switch animType {
            case .none:
                addSubview(label)
            case .scroll:
                createScrollLayer(to: label, text: text, shouldAnim: false)
            case .change:
                createScrollLayer(to: label, text: text, shouldAnim: true)
            }
            xPos += floor(label.bounds.width)
        }
    }

    func calculateAnimationFlags(
        strArray: [String],
        prevNum: Int64,
        currNum: Int64
    ) -> [AnimationType] {
        let prevFormattedStr = isCurrency ? currencyString(from: prevNum) : String(prevNum)
        let prevFormattedArr = prevFormattedStr.map { String($0) }

        var animTypes: [AnimationType] = []
        var didAnyDigitChange = false // Renamed from hasChanged for clarity
        var changedDigitIndices: Set<Int> = [] // Renamed from changePos for clarity

        // First pass: Determine initial animation types and identify changed positions
        for (index, char) in strArray.enumerated() {
            // If it's a non-digit character (like comma, decimal point), no animation
            if nonAnimTexts.contains(char) {
                animTypes.append(.none)
                continue
            }

            // Check if current position has changed
            let isActualChange: Bool
            if index < prevFormattedArr.count {
                let prevChar = prevFormattedArr[index]
                isActualChange = char != prevChar
            } else {
                // New digit position (e.g., number length increases), consider it as changed
                isActualChange = true
            }

            if isActualChange {
                didAnyDigitChange = true
                changedDigitIndices.insert(index)
                animTypes.append(.change)
            } else {
                // For unchanged digit positions, temporarily set to no animation
                animTypes.append(.none)
            }
        }

        // Decide animation type for unchanged digits based on strategy
        if didAnyDigitChange {
            if animateAllWhenChanged {
                for index in 0 ..< animTypes.count {
                    let char = strArray[index]
                    if !nonAnimTexts.contains(char) { // Ensure it's a digit/number part
                        animTypes[index] = .change
                    }
                    // Separators remain .none
                }
            } else {
                // When animateAllWhenChanged = false, apply special logic:
                // - Directly changed digits get .change.
                // - Unchanged digits to the right of the *first* changed digit get .scroll.
                // - Other unchanged digits (left of first change, or if no change) get .none.

                // Since didAnyDigitChange is true, changedDigitIndices is not empty.
                let leftmostChangedIndex = changedDigitIndices.min()! // Safe to unwrap

                for index in 0 ..< animTypes.count {
                    let char = strArray[index]

                    // Skip separators (already .none)
                    if nonAnimTexts.contains(char) {
                        continue
                    }

                    // Consider only digits that were not directly changed
                    if !changedDigitIndices.contains(index) {
                        if index > leftmostChangedIndex {
                            // For unchanged digits to the right of the leftmost changed position, show scroll animation
                            animTypes[index] = .scroll
                        } else {
                            // For unchanged digits to the left of (or at, though covered by !contains)
                            // the leftmost changed position, no animation (it's already .none)
                            animTypes[index] = .none
                        }
                    }
                    // If changedDigitIndices.contains(index), it's already .change and correctly stays so.
                }
            }
        }
        // If !didAnyDigitChange, all animTypes are already .none (correct for no changes).
        return animTypes
    }

    func getText() -> String {
        if isShowSymbol {
            "\(currSymbol) \(fullText)"
        } else {
            fullText
        }
    }

    func animate(ascending: Bool = true) {
        createAnimations(ascending: ascending)
    }

    func clean() {
        subviews.filter { $0.tag != 8898 }.forEach { $0.removeFromSuperview() }
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        scrollLayers.removeAll()
        scrollLabels.removeAll()
    }

    func createScrollLabel(text: String, origin: CGPoint) -> UILabel {
        let label = UILabel()
        label.textColor = amountColor
        label.font = font
        label.text = text
        label.textAlignment = .center

        // Calculate the text size
        let textSize = (text as NSString).size(withAttributes: [.font: font!])

        label.frame = CGRect(
            x: origin.x,
            y: origin.y,
            width: textSize.width,
            height: textSize.height
        )

        return label
    }

    /// Calculate the vertical position based on the vertical alignment setting
    func calculateVerticalPosition(for labelHeight: CGFloat) -> CGFloat {
        let frameHeight = bounds.size.height

        switch verticalAlignment {
        case .top:
            return 0
        case .center:
            return (frameHeight - labelHeight) / 2
        case .bottom:
            return frameHeight - labelHeight
        }
    }

    private func getTextHeight() -> CGFloat {
        return font.lineHeight
    }

    /// Update only the position of existing subviews without animation
    func updatePositionsOnly() {
        guard prevNumber != 0, !fullText.isEmpty else { return }

        let textHeight = getTextHeight()
        let yPos = calculateVerticalPosition(for: textHeight)

        // Update positions of all subviews
        for subview in subviews where subview.tag != 8898 {
            var frame = subview.frame
            frame.origin.y = yPos
            subview.frame = frame
        }

        // Update positions of all scroll layers
        for scrollLayer in scrollLayers {
            var frame = scrollLayer.frame
            frame.origin.y = yPos
            scrollLayer.frame = frame
        }
    }

    func createScrollLayer(to label: UILabel, text: String, shouldAnim: Bool = true) {
        let scrollLayer = CAScrollLayer()
        scrollLayer.frame = label.frame
        scrollLayers.append(scrollLayer)
        layer.addSublayer(scrollLayer)
        createContentForLayer(scrollLayer: scrollLayer, text: text, shouldAnim: shouldAnim)
    }

    func createContentForLayer(scrollLayer: CAScrollLayer, text: String, shouldAnim: Bool = true) {
        var scrollTexts: [String] = []
        guard let num = Int64(currencyString(from: text)) else {
            return
        }

        if shouldAnim {
            // If animation is needed, create scroll sequence from 0 to target digit
            scrollTexts.append("0")
            for index in 0 ... 9 {
                let str = String((num + Int64(index)) % 10)
                scrollTexts.append(currencyString(from: str))
            }
            scrollTexts.append(text)
        } else {
            // If no animation but still want scroll effect, create 0→1→2→...→9→target sequence
            // For unchanged digits, show complete 0-9 cycle then return to target digit
            for index in 0 ... 9 {
                scrollTexts.append(String(index))
            }
            scrollTexts.append(text)
        }

        var height: CGFloat = 0
        for text in scrollTexts {
            let label = UILabel()
            label.text = text
            label.textColor = amountColor
            label.font = font
            label.textAlignment = .center
            label.frame = CGRect(x: 0, y: height, width: scrollLayer.frame.width, height: scrollLayer.frame.height)
            scrollLayer.addSublayer(label.layer)
            scrollLabels.append(label)
            height = label.frame.maxY
        }
    }

    func createAnimations(ascending: Bool) {
        var offset: CFTimeInterval = 0.0

        for scrollLayer in scrollLayers {
            let maxY = scrollLayer.sublayers?.last?.frame.origin.y ?? 0.0

            let animation = CABasicAnimation(keyPath: "sublayerTransform.translation.y")
            animation.duration = duration + offset
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)

            if ascending {
                animation.fromValue = maxY
                animation.toValue = 0
            } else {
                animation.fromValue = 0
                animation.toValue = maxY
            }

            scrollLayer.scrollMode = .vertically
            scrollLayer.add(animation, forKey: nil)
            scrollLayer.scroll(to: CGPoint(x: 0, y: maxY))

            offset += durOffset
        }
    }

    func getTextSize(for text: String, with font: UIFont) -> CGSize {
        let label = UILabel(frame: .zero)
        label.font = font
        label.text = text
        label.sizeToFit()

        return label.frame.size
    }
}

extension UILabel {
    func textWidth() -> CGFloat {
        UILabel.textWidth(label: self)
    }

    class func textWidth(label: UILabel) -> CGFloat {
        textWidth(label: label, text: label.text ?? "")
    }

    class func textWidth(label: UILabel, text: String) -> CGFloat {
        textSize(font: label.font, text: text).width
    }

    class func textSize(font: UIFont, text: String) -> CGSize {
        let labelSize = text.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: .usesFontLeading,
            attributes: [NSAttributedString.Key.font: font],
            context: nil
        ).size
        return CGSize(width: ceil(labelSize.width), height: ceil(labelSize.height))
    }
}

private extension YSCurrencyAnimLabel {
    func currencyString(from num: Int64?) -> String {
        guard let num else {
            return "0"
        }
        return numberFormatter.string(from: NSNumber(value: num)) ?? "0"
    }

    func currencyString(from str: String?) -> String {
        guard let str, let num = Int64(str) else {
            return "0"
        }
        return numberFormatter.string(from: NSNumber(value: num)) ?? "0"
    }
}
