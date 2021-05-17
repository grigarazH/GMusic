//
//  ViewController.swift
//  GMusic
//
//  Created by Григорий Сухотин on 26.04.2021.
//

import UIKit
import FirebaseAuth

class ViewController: UIViewController {
    @IBOutlet weak var emailTF: UITextField!
    @IBOutlet weak var passwordTF: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let auth = Auth.auth()
        if let user = auth.currentUser {
            self.performSegue(withIdentifier: "loginToMainAppSegue", sender: self)
        }
    }

    @IBAction func loginButtonClick(_ sender: UIButton) {
        let auth = Auth.auth()
        guard let email = emailTF.text else {
            return}
        guard let password = passwordTF.text else {
            return}
        auth.signIn(withEmail: email, password: password) { result, error in
            guard let result = result else {
                let loginAlertController = UIAlertController(title: "Ошибка", message: "Неверный E-mail или пароль", preferredStyle: .alert)
                loginAlertController.addAction(UIAlertAction(title: "ОК", style: .default))
                self.present(loginAlertController, animated: true)
                return
            }
            self.performSegue(withIdentifier: "loginToMainAppSegue", sender: self)
        }
    }
    @IBAction func unwind(unwindSegue: UIStoryboardSegue) {
        
    }
}

