//
//  YSCurrencyAnimLabel.swift
//  YSCurrencyAnimLabel
//
//  Created by Joseph on 2025/6/5.
//

import QuartzCore
import UIKit

// MARK: - YSCurrencyAnimLabel

public class YSCurrencyAnimLabel: UILabel {
    public var isCurrency = true
    public var showSymbol = true
    public var numberFormatter: NumberFormatter = .init() {
        didSet {
            // Automatically re-format the display when formatter changes if content exists
            if prevNumber != 0, !areFormattersEqual(oldValue, numberFormatter) {
                refreshDisplayWithoutAnimation()
            }
        }
    }

    /// Whether to show animation for all digit positions even if their values haven't changed
    /// When set to true, if any digit changes, all digit positions will show scroll animation
    /// When set to false, only digits that actually changed will show animation
    public var animateAllWhenChanged = false

    public private(set) var fullText = ""

    private var amountColor: UIColor = .black
    private var currSymbol: String = "$"
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

    override public init(frame: CGRect) {
        super.init(frame: frame)
        textColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setCurrency(symbol: String) {
        currSymbol = symbol
    }
}

private extension YSCurrencyAnimLabel {
    func refreshDisplayWithoutAnimation() {
        guard prevNumber != 0 else {
            return
        }

        // Re-format text
        if isCurrency {
            fullText = currencyString(from: prevNumber)
        } else {
            fullText = String(prevNumber)
        }

        text = getText()

        // Clear existing subviews and layers
        clean()

        // Recreate display content without animation
        let strArray = fullText.map { String($0) }
        var xPos: CGFloat = 0
        let yPos: CGFloat = 0
        let frameW = bounds.size.width
        let textW = textWidth()

        if textAlignment == .center {
            xPos = (frameW - textW) / 2
        } else if textAlignment == .right {
            xPos = frameW - textW
        }

        if showSymbol {
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
    func updateSubviews(prevNum: Int64 = 0, currNum: Int64) {
        clean()

        layoutIfNeeded()
        let strArray = fullText.map { String($0) }
        var xPos: CGFloat = 0
        let yPos: CGFloat = 0
        let frameW = bounds.size.width
        let textW = textWidth() // getTextSize(for: getText(), with: font).width
        if textAlignment == .center {
            xPos = (frameW - textW) / 2

        } else if textAlignment == .right {
            xPos = frameW - textW
        }

        if showSymbol {
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
                // No animation, use static label
                addSubview(label)
            case .scroll:
                // Scroll animation (0-9-0 effect for unchanged digits)
                createScrollLayer(to: label, text: text, shouldAnim: false)
            case .change:
                // Change animation (digits that actually changed)
                createScrollLayer(to: label, text: text, shouldAnim: true)
            }
            xPos += floor(label.bounds.width)
        }
    }

    enum AnimationType {
        case none // No animation (identical digits or separators)
        case scroll // Scroll animation (0-9-0 effect for unchanged digits)
        case change // Change animation (digits that actually changed)
    }

    func calculateAnimationFlags(
        strArray: [String],
        prevNum: Int64,
        currNum: Int64
    ) -> [AnimationType] {
        // Get formatted previous number string (including thousand separators, etc.)
        let prevFormattedStr = isCurrency ? currencyString(from: prevNum) : String(prevNum)
        let prevFormattedArr = prevFormattedStr.map { String($0) }

        var animTypes: [AnimationType] = []
        var hasChanged = false
        var changePos: Set<Int> = [] // Record positions that changed

        // Step 1: Determine which positions have changed
        for (index, char) in strArray.enumerated() {
            // If it's a non-digit character (like comma, decimal point), no animation
            if nonAnimTexts.contains(char) {
                animTypes.append(.none)
                continue
            }

            // Check if current position has changed
            let isChanged: Bool
            if index < prevFormattedArr.count {
                let prevChar = prevFormattedArr[index]
                isChanged = char != prevChar
            } else {
                // New digit position, consider it as changed
                isChanged = true
            }

            if isChanged {
                hasChanged = true
                changePos.insert(index)
                animTypes.append(.change)
            } else {
                // For unchanged digit positions, temporarily set to no animation
                animTypes.append(.none)
            }
        }

        // Step 2: Decide animation type for unchanged digits based on strategy
        if hasChanged {
            if animateAllWhenChanged {
                // When animateAllWhenChanged = true, all digits show change animation
                for index in 0 ..< animTypes.count {
                    let char = strArray[index]
                    if !nonAnimTexts.contains(char) {
                        animTypes[index] = .change
                    }
                }
            } else {
                // When animateAllWhenChanged = false, apply special logic

                // Find the highest position that changed
                let highestPos = changePos.min() ?? -1

                for index in 0 ..< animTypes.count {
                    let char = strArray[index]

                    // Skip separators
                    if nonAnimTexts.contains(char) {
                        continue
                    }

                    // If this position hasn't changed
                    if !changePos.contains(index) {
                        if index > highestPos {
                            // For unchanged digits to the right of changed position, show scroll animation
                            animTypes[index] = .scroll
                        } else {
                            // For unchanged digits to the left of or at changed position, no animation
                            animTypes[index] = .none
                        }
                    }
                }
            }
        }

        return animTypes
    }

    func getText() -> String {
        if showSymbol {
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
        label.frame.origin = origin
        label.textColor = amountColor
        label.font = font
        label.text = text
        label.textAlignment = .center
        label.sizeToFit()
        return label
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
