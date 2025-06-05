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

    override func viewDidLoad() {
        super.viewDidLoad()
        stepper.minimumValue = 0
        stepper.maximumValue = 10
        stepper.value = 5
        stepper.stepValue = 1

        demo_1()
    }

    func demo_1() {
        label_1.textColor = .systemBlue
        label_1.backgroundColor = .lightGray
        label_1.setCurrency(symbol: "¥")
        label_1.setNumber(number)
        label_1.isCurrency = true

        view.addSubview(label_1)
        label_1.frame = CGRect(x: 20, y: 100, width: 300, height: 35)
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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
