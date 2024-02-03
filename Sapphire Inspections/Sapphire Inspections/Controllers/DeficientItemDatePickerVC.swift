//
//  DeficientItemDatePickerVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 4/15/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

protocol DeficientItemDatePickerVCDelegate: class {
    func deficientItemDateUpdated(date: Date, dateDay: String, element: DICellElement)
}

class DeficientItemDatePickerVC: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var timeZonePicker: UIPickerView!
    @IBOutlet weak var navItem: UINavigationItem!
    @IBOutlet var doneButton: UIBarButtonItem!
    
    var headerText = ""
    var element: DICellElement?
    weak var delegate: DeficientItemDatePickerVCDelegate?
    
    var timeZones: [String] = []
    var selectedTimeZone = TimeZone.current
    
    var allowAnyFutureDate = false
    var deficientItemHasUpdates = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = headerText
        navItem.title = headerText
//        if let date = date {
//            datePicker.date = date
//        }
        
        timeZones = TimeZone.knownTimeZoneIdentifiers
        
        applySelectedTimeZoneAndSetTimeOfDay()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
        if let index = timeZones.firstIndex(of: selectedTimeZone.identifier) {
            timeZonePicker.selectRow(index, inComponent: 0, animated: true)
        }
        
        updateNavButtons()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateNavButtons() {
        if deficientItemHasUpdates {
            addDoneButton()
            // Now using table button to save
            //            addSaveButton()
        } else {
            removeDoneButton()
        }
    }
    
    func addDoneButton() {
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if !rightBarButtonItems.contains(doneButton) {
            rightBarButtonItems.append(doneButton)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    func removeDoneButton() {
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if let index = rightBarButtonItems.index(of: doneButton) {
            rightBarButtonItems.remove(at: index)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    func applySelectedTimeZoneAndSetTimeOfDay() {
        datePicker.timeZone = selectedTimeZone

        let cal = Calendar(identifier: .gregorian)
        var startOfDayDateForTimeZone = cal.startOfDay(for: Date())
        
        // Set Offst for selected offset, vs current.
        let currentTimeZoneSecondsOffset = (TimeZone.current.secondsFromGMT() / 3600) * 3600
        let selectedTimeZoneSecondsOffset = (selectedTimeZone.secondsFromGMT() / 3600) * 3600
        let deltaOffsetSeconds = selectedTimeZoneSecondsOffset - currentTimeZoneSecondsOffset
        startOfDayDateForTimeZone.addTimeInterval(Double(deltaOffsetSeconds))
        //.addingTimeInterval(Double(selectedTimeZone.secondsFromGMT()))
        
        let oneDay: TimeInterval = 60 * 60 * 24
        let twoWeeks: TimeInterval = 60 * 60 * 24 * 14
        let oneDayMinusOneSec: TimeInterval = 60 * 60 * 24 - 1  // To put time at 11:59:59pm
        datePicker.minimumDate = startOfDayDateForTimeZone.addingTimeInterval(oneDay + oneDayMinusOneSec) // Tomorrow, end of day
        
        if !allowAnyFutureDate {
            // 2 weeks out, end of day
            datePicker.maximumDate = Date(timeInterval: twoWeeks + oneDayMinusOneSec, since: startOfDayDateForTimeZone)
        }
        datePicker.setDate(startOfDayDateForTimeZone.addingTimeInterval(oneDay), animated: true)
    }
    
    // MARK: - DatePicker Delegate
    
    @IBAction func datePickerChangedValue(_ sender: Any) {
        callDelegate()
    }

    // MARK: - Picker

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        
        return timeZones.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        return timeZones[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        selectedTimeZone = TimeZone(identifier: timeZones[row]) ?? TimeZone.current
        applySelectedTimeZoneAndSetTimeOfDay()
        callDelegate()
    }
    
    func callDelegate() {
        if let element = element {
            let formatter = DateFormatter()
            formatter.timeZone = selectedTimeZone
            formatter.dateFormat = "MM/dd/yyyy"
//            formatter.dateStyle = DateFormatter.Style.short
//            formatter.timeStyle = DateFormatter.Style.none
            delegate?.deficientItemDateUpdated(date: datePicker.date, dateDay: formatter.string(from: datePicker.date), element: element)
        }
        
        deficientItemHasUpdates = true
        updateNavButtons()
    }

    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
