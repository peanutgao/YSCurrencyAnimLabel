//
//  ViewController.swift
//  YSCurrencyAnimLabel
//
//  Created by peanutgao on 06/05/2025.
//  Copyright (c) 2025 peanutgao. All rights reserved.
//

import UIKit
import YSCurrencyAnimLabel

class ViewController: UIViewController {
    var number: Int64 = 800_000

    @IBOutlet var stepper: UIStepper!
    let label_1 = YSCurrencyAnimLabel()
    let label_2 = YSCurrencyAnimLabel()
    let label_3 = YSCurrencyAnimLabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        stepper.minimumValue = 0
        stepper.maximumValue = 10
        stepper.value = 5
        stepper.stepValue = 1

        demo_1()
        demo_2()
        demo_3()
    }

    func demo_1() {
        label_1.textColor = .systemBlue
        label_1.backgroundColor = .lightGray
        label_1.setCurrency(symbol: "¥")
        label_1.setNumber(number)
        label_1.isCurrency = true
        label_1.numberFormatter = Formatter.idroNumber
        label_1.animateAllWhenChanged = false

        view.addSubview(label_1)
        label_1.frame = CGRect(x: 20, y: 100, width: 300, height: 35)
    }

    func demo_2() {
        label_2.textColor = .systemRed
        label_2.backgroundColor = .lightGray
        label_2.setCurrency(symbol: "$")
        label_2.setNumber(number)
        label_2.isCurrency = true
        label_2.numberFormatter = Formatter.idroNumber
        label_2.animateAllWhenChanged = true

        view.addSubview(label_2)
        label_2.frame = CGRect(x: 20, y: 160, width: 300, height: 35)
    }


    func demo_3() {
        label_3.textColor = .systemRed
        label_3.backgroundColor = .lightGray
        label_3.setCurrency(symbol: "$")
        label_3.isCurrency = true
        label_3.animateAllWhenChanged = false

        label_3.setNumber(number)

        label_3.numberFormatter = Formatter.idroNumber

        view.addSubview(label_3)
        label_3.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label_3.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label_3.topAnchor.constraint(equalTo: label_2.bottomAnchor, constant: 20),
            label_3.heightAnchor.constraint(equalToConstant: 35)
        ])
    }

    @IBAction func valueChanged(_ sender: UIStepper) {
        let newValue: Int64 = if sender.value == 5 {
            number
        } else if sender.value > 5 {
            number + Int64(sender.value - 5) * 1000
        } else {
            number - Int64(5 - sender.value) * 1000
        }

        label_1.setNumber(newValue)
        label_2.setNumber(newValue)
        label_3.setNumber(newValue)
    }
}

public extension Formatter {
    static let idroNumber: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        return formatter
    }()
}
