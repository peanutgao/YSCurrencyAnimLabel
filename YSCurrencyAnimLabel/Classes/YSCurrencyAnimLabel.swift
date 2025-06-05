//
//  YSCurrencyAnimLabel.swift
//  YSCurrencyAnimLabel
//
//  Created by Joseph on 2025/6/5.
//

import UIKit
import QuartzCore

// MARK: - SPLabel

public class YSCurrencyAnimLabel: UILabel {
    public var isCurrency = true
    public var showSymbol = true
    public var numberFormatter: NumberFormatter = .init()
        
    public private(set) var fullText = ""

    private var amountColor: UIColor = .black
    private var currencySymbol: String = "$"
    private var scrollLayers: [CAScrollLayer] = []
    private var scrollLabels: [UILabel] = []
    private let duration = 0.7
    private let durationOffset = 0.2
    private let textsNotAnimated = [",", "."]

    // swiftlint:disable:next implicitly_unwrapped_optional
    public override var textColor: UIColor! {
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
        updateSubviews()
        animate()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        textColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setCurrency(symbol: String) {
        currencySymbol = symbol
    }
}

private extension YSCurrencyAnimLabel {
    func updateSubviews() {
        clean()

        layoutIfNeeded()
        let stringArray = fullText.map { String($0) }
        var x: CGFloat = 0
        let y: CGFloat = 0
        let frameWidth = bounds.size.width
        let textWidth =  textWidth() // getTextSize(for: getText(), with: font).width
        if textAlignment == .center {
            x = (frameWidth - textWidth) / 2

        } else if textAlignment == .right {
            x = frameWidth - textWidth
        }

        if showSymbol {
            let symbolLabel = createScrollLabel(text: "\(currencySymbol) ", origin: CGPoint(x: x, y: y))
            addSubview(symbolLabel)
            x += symbolLabel.bounds.width
        }

        for text in stringArray {
            let label = createScrollLabel(text: text, origin: CGPoint(x: x, y: y))
            if textsNotAnimated.contains(text) {
                addSubview(label)
            } else {
                createScrollLayer(to: label, text: text)
            }
            x += floor(label.bounds.width)
        }
    }

    func getText() -> String {
        if showSymbol {
            "\(currencySymbol) \(fullText)"
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

    func createScrollLayer(to label: UILabel, text: String) {
        let scrollLayer = CAScrollLayer()
        scrollLayer.frame = label.frame
        scrollLayers.append(scrollLayer)
        layer.addSublayer(scrollLayer)
        createContentForLayer(scrollLayer: scrollLayer, text: text)
    }

    func createContentForLayer(scrollLayer: CAScrollLayer, text: String) {
        var textsForScroll: [String] = []
        guard let number = Int64(currencyString(from: text)) else {
            return
        }
        
        textsForScroll.append("0")
        for i in 0 ... 9 {
            let str = String((number + Int64(i)) % 10)
            textsForScroll.append(currencyString(from: str))
        }
        textsForScroll.append(text)

        var height: CGFloat = 0
        for text in textsForScroll {
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

            offset += durationOffset
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
    func currencyString(from number: Int64?) -> String {
        guard let number else {
            return "0"
        }
        return numberFormatter.string(from: NSNumber(value: number)) ?? "0"
    }
    
    func currencyString(from string: String?) -> String {
        guard let string, let number = Int64(string) else {
            return "0"
        }
        return numberFormatter.string(from: NSNumber(value: number)) ?? "0"
    }
}
