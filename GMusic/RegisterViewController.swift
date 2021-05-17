//
//  RegisterViewController.swift
//  GMusic
//
//  Created by Григорий Сухотин on 28.04.2021.
//

import UIKit
import FirebaseAuth


class RegisterViewController: UIViewController {

    @IBOutlet weak var emailTF: UITextField!
    @IBOutlet weak var passTF: UITextField!
    @IBOutlet weak var confPassTF: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    @IBAction func registerClick(_ sender: UIButton) {
        let auth = Auth.auth()
        let emptyFieldAlertController = UIAlertController(title: "Ошибка", message: "Заполните все поля", preferredStyle: .alert)
        emptyFieldAlertController.addAction(UIAlertAction(title: "ОК", style: .default))
        guard let email = emailTF.text else {
            present(emptyFieldAlertController, animated: true)
            return}
        guard let password = passTF.text else {
            present(emptyFieldAlertController, animated: true)
            return}
        guard let confPass = confPassTF.text else {
            present(emptyFieldAlertController, animated: true)
            return}
        guard email != "" || password != "" || confPass != "" else{
            present(emptyFieldAlertController, animated: true)
            return
        }
        guard password == confPass else {
            let passCheckAlertController = UIAlertController(title: "Ошибка", message: "Пароли не совпадают", preferredStyle: .alert)
            passCheckAlertController.addAction(UIAlertAction(title: "ОК", style: .default))
            present(passCheckAlertController, animated: true)
            return
        }
        auth.createUser(withEmail: email, password: password) { result, error in
            guard result != nil else {
                guard let errorCode = (error as NSError?)?.code else {return}
                switch errorCode {
                case AuthErrorCode.invalidEmail.rawValue:
                    let invalidEmailAlertController = UIAlertController(title: "Ошибка", message: "Неправильный E-mail", preferredStyle: .alert)
                    invalidEmailAlertController.addAction(UIAlertAction(title: "ОК", style: .default))
                    self.present(invalidEmailAlertController, animated: true)
                case AuthErrorCode.weakPassword.rawValue:
                    let weakPWAlertController = UIAlertController(title: "Ошибка", message: "Пароль слишком слабый", preferredStyle: .alert)
                    weakPWAlertController.addAction(UIAlertAction(title: "ОК", style: .default))
                    self.present(weakPWAlertController, animated: true)
                case AuthErrorCode.emailAlreadyInUse.rawValue:
                    let emailInUseAlertController = UIAlertController(title: "Ошибка", message: "E-mail уже используется", preferredStyle: .alert)
                    emailInUseAlertController.addAction(UIAlertAction(title: "ОК", style: .default))
                    self.present(emailInUseAlertController, animated: true)
                default:
                    return
                }
                return
            }
            let successRegisterAlertController = UIAlertController(title: "Успешная регистрация", message: "Пользователь успешно зарегистрирован ", preferredStyle: .alert)
            successRegisterAlertController.addAction(UIAlertAction(title: "ОК", style: .default))
            self.performSegue(withIdentifier: "unwindToLogin", sender: self)
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
