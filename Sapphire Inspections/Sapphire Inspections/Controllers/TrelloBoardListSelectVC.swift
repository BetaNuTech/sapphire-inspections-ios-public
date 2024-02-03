//
//  TrelloBoardListSelectVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/18/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

struct TrelloBoard {
    var boardName = ""
    var boardId = ""
    var orgId = ""
    var orgName = ""
}

struct TrelloOrganization {
    var orgId = ""
    var orgName = ""
}

struct TrelloList {
    var listName = ""
    var listId = ""
}

class TrelloBoardListSelectVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var propertyKey: String?
    
    var boards: [TrelloBoard] = []
    var organizations: [TrelloOrganization] = []
    var lists: [TrelloList] = []
    
    var listsNotBoards = false
    var setting = TrelloSetting.open
    
    var currentBoardId: String?
    var currentListId: String?

    var filterString = ""
    var filteredBoards: [TrelloBoard] = []
    var filteredLists: [TrelloList] = []
    

    override func viewDidLoad() {
        super.viewDidLoad()
        

        // Defaults
        tableView.rowHeight = UITableView.automaticDimension;
        
        if listsNotBoards {
            tableView.estimatedRowHeight = 50.0;
            loadLists()
        } else {
            tableView.estimatedRowHeight = 61.0;
            loadBoards()
        }
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if listsNotBoards {
            return filteredLists.count
        }
        
        return filteredBoards.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if listsNotBoards {
            let cell = tableView.dequeueReusableCell(withIdentifier: "trelloListCell") as! TrelloListTVCell
            let list = filteredLists[indexPath.row]

            cell.listName.text = list.listName
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "trelloBoardCell") as! TrelloBoardTVCell
        let board = filteredBoards[indexPath.row]
        cell.boardName.text = board.boardName
        cell.teamName.text = board.orgName
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    // MARK: UITableView Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if listsNotBoards {
            let list = filteredLists[indexPath.row]
            itemSelected(itemId: list.listId, itemName: list.listName)
            currentListId = list.listId
        } else {
            let board = filteredBoards[indexPath.row]
            itemSelected(itemId: board.boardId, itemName: board.boardName)
            currentBoardId = board.boardId
        }
//        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: UISearchBarDelegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        filterString = searchText
        filterBoardsListsAndReloadTable()
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func filterBoardsListsAndReloadTable() {
        if filterString == "" {
            filteredBoards = boards
            filteredLists = lists
        } else {
            filteredBoards = boards.filter(
                { $0.boardName.lowercased().contains(filterString.lowercased()) || $0.orgName.lowercased().contains(filterString.lowercased())
                }
            )
            filteredLists = lists.filter(
                { $0.listName.lowercased().contains(filterString.lowercased())
                }
            )
        }
        
        tableView.reloadData()
        showCurrentSelection(scrollPos: .none)
    }

    // MARK: Private Methods
    
    func loadBoards() {
        
        if let user = currentUser {
            user.getIDToken { [weak self] (token, error) in
                if let token = token {
                    let headers: HTTPHeaders = [
                        "Authorization": "FB-JWT \(token)",
                        "Content-Type": "application/json"
                    ]
                    
                    presentHUDForConnection()
                    AF.request(getTrelloBoardsURLString, headers: headers).responseJSON { [weak self] response in
                        debugPrint(response)
                        
                        if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                            if let data = response.data  {
                                var newBoards: [TrelloBoard] = []
                                var newOrgs: [TrelloOrganization] = []
                                let json = JSON(data)
                                if let dataJSONArray = json["data"].array {
                                    for elementJSON in dataJSONArray {
                                        var board: TrelloBoard = TrelloBoard()
                                        board.boardId = elementJSON["id"].stringValue
                                        if let attributesJSONDict = elementJSON["attributes"].dictionary {
                                            board.boardName = attributesJSONDict["name"]?.stringValue ?? ""
                                        }
                                        if let orgJSONDict = elementJSON["relationships"]["trelloOrganization"]["data"].dictionary {
                                            board.orgId = orgJSONDict["id"]?.stringValue ?? ""
                                        }
                                        newBoards.append(board)
                                    }
                                    self?.boards = newBoards
                                } else {
                                    print("No Board Data")
                                }
                                if let includedJSONArray = json["included"].array {
                                    for elementJSON in includedJSONArray {
                                        var org: TrelloOrganization = TrelloOrganization()
                                        org.orgId = elementJSON["id"].stringValue
                                        if let attributesJSONDict = elementJSON["attributes"].dictionary {
                                            org.orgName = attributesJSONDict["name"]?.stringValue ?? ""
                                        }
                                        newOrgs.append(org)
                                    }
                                    self?.organizations = newOrgs
                                } else {
                                    print("No Board Data")
                                }
                                if !newBoards.isEmpty {
                                    self?.updateOrganizationsForBoards()
                                    self?.sortBoardsAndLists()
                                    self?.filterBoardsListsAndReloadTable()
                                    self?.showCurrentSelection(scrollPos: .middle)
                                }
                            }
                        } else {
                           let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                           let alertController = UIAlertController(title: "Error Retrieving Trello Boards", message: errorMessage, preferredStyle: .alert)
                           let okayAction = UIAlertAction(title: "OK", style: .default)
                           alertController.addAction(okayAction)
                           self?.present(alertController, animated: true, completion: nil)
                        }
                                                
                        dismissHUDForConnection()
                    }
                }
            }
        }
    }
    
    func loadLists() {
        
        guard let boardId = currentBoardId, boardId != "" else {
            print("ERROR: currentBoardId is not set")
            return
        }
        
        if let user = currentUser {
            user.getIDToken { [weak self] (token, error) in
                if let token = token {
                    let headers: HTTPHeaders = [
                        "Authorization": "FB-JWT \(token)",
                        "Content-Type": "application/json"
                    ]
                    
                    presentHUDForConnection()
                    AF.request(getTrelloListsURLString(boardId: boardId), headers: headers).responseJSON { [weak self] response in
                        debugPrint(response)
                        
                        if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                            if let data = response.data  {
                                var newLists: [TrelloList] = []
                                let json = JSON(data)
                                if let dataJSONArray = json["data"].array {
                                    for elementJSON in dataJSONArray {
                                        var list: TrelloList = TrelloList()
                                        list.listId = elementJSON["id"].stringValue
                                        if let attributesJSONDict = elementJSON["attributes"].dictionary {
                                            list.listName = attributesJSONDict["name"]?.stringValue ?? ""
                                        }
                                        newLists.append(list)
                                    }
                                    self?.lists = newLists
                                }
                                
                                self?.sortBoardsAndLists()
                                self?.filterBoardsListsAndReloadTable()
                                self?.showCurrentSelection(scrollPos: .middle)
                                //                            self?.showCurrentSelection()
                                
                            }
                        } else {
                            let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                            let alertController = UIAlertController(title: "Error Retrieving Trello Lists", message: errorMessage, preferredStyle: .alert)
                            let okayAction = UIAlertAction(title: "OK", style: .default)
                            alertController.addAction(okayAction)
                            self?.present(alertController, animated: true, completion: nil)
                        }
                        
                        dismissHUDForConnection()
                    }
                }
            }
        }
    }
    
    func updateOrganizationsForBoards() {
        for (index, board) in boards.enumerated() {
            if board.orgId != "" {
                if let org = organizations.first(where: {$0.orgId == board.orgId }) {
                    boards[index].orgName = org.orgName
                }
            }
        }
    }
    
    func sortBoardsAndLists() {
        boards.sort(by: { $0.boardName.lowercased() < $1.boardName.lowercased() } )
        lists.sort(by: { $0.listName.lowercased() < $1.listName.lowercased() } )
    }
    
    func showCurrentSelection(scrollPos: UITableView.ScrollPosition) {
        if listsNotBoards && currentListId != nil {
            if let index = filteredLists.firstIndex(where: { $0.listId == currentListId }) {
                tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: scrollPos)
            }
        } else if currentBoardId != nil {
            if let index = filteredBoards.firstIndex(where: { $0.boardId == currentBoardId }) {
                tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: scrollPos)
            }
        }
    }
    
    
    func itemSelected(itemId: String, itemName: String) {
        print("board selected")
        guard let propertyKey = propertyKey else {
            print("ERROR: propertyKey not set")
            return
        }
        
        var keyValues: [String : AnyObject] = [:]
        switch setting {
        case .open:
            if listsNotBoards {
                keyValues = [
                    "openList" : itemId as NSString,
                    "openListName" : itemName as NSString
                ]
            } else {
                keyValues = [
                    "openBoard" : itemId as NSString,
                    "openBoardName" : itemName as NSString,
                    "openList" : NSNull(),
                    "openListName" : NSNull()
                ]
            }
        case .closed:
            if listsNotBoards {
                keyValues = [
                    "closedList" : itemId as NSString,
                    "closedListName" : itemName as NSString
                ]
            } else {
                keyValues = [
                    "closedBoard" : itemId as NSString,
                    "closedBoardName" : itemName as NSString,
                    "closedList" : NSNull(),
                    "closedListName" : NSNull()
                ]
            }
        }
        
        dbDocumentIntegrationTrelloPropertyWith(propertyId: propertyKey).setData(keyValues, merge: true)
    }
    
    func listSelected(listId: String, listName: String) {
        print("list selected")
    }
    
}

class TrelloBoardTVCell: UITableViewCell {
    
    @IBOutlet weak var boardName: UILabel!
    @IBOutlet weak var teamName: UILabel!

}

class TrelloListTVCell: UITableViewCell {
    
    @IBOutlet weak var listName: UILabel!
    
}
