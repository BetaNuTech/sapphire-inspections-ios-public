//
//  BidTimelineEditTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/22/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

protocol BidTimelineEditTVCellDelegate: class {
    func startAtUpdated(date: Date)
    func completeAtUpdated(date: Date)
}

class BidTimelineEditTVCell: UITableViewCell {

    @IBOutlet weak var datePicker1: UIDatePicker!
    @IBOutlet weak var datePicker2: UIDatePicker!
    
    weak var delegate: BidTimelineEditTVCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
                
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setDates(startAtDate: Date?, completeAtDate: Date?) {
        if let startAtDate = startAtDate {
            datePicker1.date = startAtDate
            datePicker1.alpha = 1.0
        } else {
            datePicker1.alpha = 0.25
        }
        if let completeAtDate = completeAtDate {
            datePicker2.date = completeAtDate
            datePicker2.alpha = 1.0
        } else {
            datePicker2.alpha = 0.25
        }
    }
    
    // MARK: Actions

    @IBAction func datePicker1ChangedValue(_ sender: UIDatePicker) {
        sender.alpha = 1.0
        
        delegate?.startAtUpdated(date: sender.date)
        
        if datePicker2.date.timeIntervalSince1970 < sender.date.timeIntervalSince1970 {
            datePicker2.date = sender.date
            delegate?.completeAtUpdated(date: sender.date)
        }
    }
    
    @IBAction func datePicker2ChangedValue(_ sender: UIDatePicker) {
        sender.alpha = 1.0

        delegate?.completeAtUpdated(date: sender.date)
        
        if datePicker1.date.timeIntervalSince1970 > sender.date.timeIntervalSince1970 {
            datePicker1.date = sender.date
            delegate?.startAtUpdated(date: sender.date)
        }
    }
    
}

