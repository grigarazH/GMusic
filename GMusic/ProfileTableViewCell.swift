//
//  ProfileTableViewCell.swift
//  GMusic
//
//  Created by Григорий Сухотин on 31.05.2021.
//

import UIKit

class ProfileTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    @IBOutlet weak var accountName: UILabel!
    @IBOutlet weak var accountStatus: UILabel!
    @IBOutlet weak var accountButton: UIButton!
    
    var accountAction: (() -> Void)!
    @IBAction func accountButtonClick(_ sender: Any) {
        accountAction()
    }
    
}
