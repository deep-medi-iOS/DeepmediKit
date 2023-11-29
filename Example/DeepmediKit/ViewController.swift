//
//  ViewController.swift
//  DeepmediKit
//
//  Created by demianjun@gmail.com on 06/19/2023.
//  Copyright (c) 2023 demianjun@gmail.com. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let goFaceButton = UIButton()
    let goFingerButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.ui()
    }
    
    func ui() {
        [
            goFaceButton,
            goFingerButton
        ]
            .forEach { self.view.addSubview($0) }
        
        goFaceButton.translatesAutoresizingMaskIntoConstraints = false
        goFingerButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            goFaceButton.topAnchor.constraint(equalTo: self.view.topAnchor),
            goFaceButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            goFaceButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            goFaceButton.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.5),
        ])
        NSLayoutConstraint.activate([
            goFingerButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            goFingerButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            goFingerButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            goFingerButton.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.5),
        ])
        
        goFaceButton.backgroundColor = .red
        goFingerButton.backgroundColor = .blue
        goFaceButton.titleLabel?.font = .systemFont(ofSize: 35)
        goFaceButton.setTitle("Face", for: .normal)
        goFaceButton.setTitleColor(.white, for: .normal)
        goFingerButton.titleLabel?.font = .systemFont(ofSize: 35)
        goFingerButton.setTitle("Finger", for: .normal)
        goFingerButton.setTitleColor(.white, for: .normal)
        
        goFaceButton.addTarget(self, action: #selector(didTapButton(_:)), for: .touchUpInside)
        goFingerButton.addTarget(self, action: #selector(didTapButton(_:)), for: .touchUpInside)
    }
    
    @objc func didTapButton(_ sender: UIButton) {
        let faceVC = FaceViewController()
        let fingerVC = FingerViewController()
        
        if sender.titleLabel?.text == "Face" {
            faceVC.modalPresentationStyle = .overFullScreen
            self.present(faceVC, animated: true)
        } else {
            fingerVC.modalPresentationStyle = .overFullScreen
            self.present(fingerVC, animated: true)
        }
    }
}

