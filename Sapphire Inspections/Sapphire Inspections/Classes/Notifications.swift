//
//  Notifications.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 9/20/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import Foundation
import SwiftyJSON

class Notifications {
    
    class func editor(profile: UserProfile) -> String {
        var editor = "(\(profile.email ?? "<email missing>"))"
        if let lastName = profile.lastName {
            editor = lastName + " " + editor
        }
        if let firstName = profile.firstName {
            editor = firstName + " " + editor
        }
        
        return editor
    }
    
    class func editorShortName(profile: UserProfile) -> String {
        var editor = ""
        if let lastName = profile.lastName {
            editor = lastName
        }
        if let firstName = profile.firstName {
            if editor != "" {
                editor = firstName + " " + editor
            } else {
                editor = firstName
            }
        }
        if editor == "" {
            editor = "\(profile.email ?? "<email missing>")"
        }
        
        return editor
    }
    
    class func notificationData() -> (editor: String?, editorShortName: String?, newNotification: NotificationModel?) {
        guard let currentUser = currentUser else {
            print("ERROR: Current User is nil")
            return (editor: nil, editorShortName: nil, newNotification: nil)
        }
        guard let currentUserProfile = currentUserProfile else {
            print("ERROR: Current User Profile is nil")
            return (editor: nil, editorShortName: nil, newNotification: nil)
        }
        
        guard let newNotification = NotificationModel(JSONString: "{}") else {
            print("ERROR: New NotificationModel returned nil")
            return (editor: nil, editorShortName: nil, newNotification: nil)
        }
        
        newNotification.creator = currentUser.uid
        let editor = Notifications.editor(profile: currentUserProfile)
        let editorShortName = Notifications.editorShortName(profile: currentUserProfile)
        
        // Version and Build #
        newNotification.userAgent = userAgent // Global
        return (editor: editor, editorShortName, newNotification: newNotification)
    }
    
    class func env() -> String {
        #if RELEASE_BLUESTONE
        return ""
        #elseif RELEASE_STAGING
        return "[STAGING] "
        #else
        return "[STAGING] "
        #endif
    }
    
    // MARK: - USERS
    
    class func sendUserCreation(newUserProfile: UserProfile) {
        let notificationData = Notifications.notificationData()
        guard let newNotification = notificationData.newNotification else {
            return
        }

        newNotification.title = Notifications.env() + "New User Login"
        newNotification.summary = "\(newUserProfile.email ?? "<missing email>") just signed in for the first time and needs access granted."
        let markdownBody = "@channel: `\(newUserProfile.email ?? "<missing email>")` just signed in for the first time and needs access granted."
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendUserDisabled(userProfile: UserProfile) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "User Disabled"
        let name = "\(userProfile.firstName ?? "") \(userProfile.lastName ?? "")"
        newNotification.summary = "The account for \(userProfile.email ?? "<missing email>") disabled by \(editorShortName)"
        var markdownBody = "`The user account for \(name) (\(userProfile.email ?? "<missing email>")) disabled."
        markdownBody += "*Disabled by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendUserUpdate(prevUserProfile: UserProfile, newUserProfile: UserProfile, keyProperties: [KeyProperty], keyTeams: [KeyTeam]) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        let prevUserAdminAccess = prevUserProfile.admin
        let newUserAdminAccess = newUserProfile.admin

        let prevUserCorporateAccess = prevUserProfile.corporate
        let newUserCorporateAccess = newUserProfile.corporate

        var prevPropertyCount = 0
        var newPropertyCount = 0
        for keyProperty in keyProperties {
            if prevUserProfile.properties[keyProperty.key] != nil {
                prevPropertyCount += 1
            }
            if newUserProfile.properties[keyProperty.key] != nil {
                newPropertyCount += 1
            }
        }
        
        var prevTeamCount = 0
        var newTeamCount = 0
        for keyTeam in keyTeams {
            if prevUserProfile.teams[keyTeam.key] != nil {
                prevTeamCount += 1
            }
            if newUserProfile.teams[keyTeam.key] != nil {
                newTeamCount += 1
            }
        }

        newNotification.title = Notifications.env() + "User Update"
        newNotification.summary = "The account for \(newUserProfile.email ?? "<missing email>") was just updated by \(editorShortName)"
        var markdownBody =  "Previous Data:\n"
        //            markdownBody += prevDataJSONString
        markdownBody += "```\n"
        markdownBody += "Name: \(prevUserProfile.firstName ?? "") \(prevUserProfile.lastName ?? "")\n"
        markdownBody += "Email: \(prevUserProfile.email ?? "<missing email>")\n"
        markdownBody += "Admin Access: \(prevUserAdminAccess ? "true" : "false")\n"
        markdownBody += "Corporate Access: \(prevUserCorporateAccess ? "true" : "false")\n"
        markdownBody += "Team Level Access Count: \(prevTeamCount)\n"
        markdownBody += "Property Level Access Count: \(prevPropertyCount)\n"
        markdownBody += "```\n"
        markdownBody += "New Data:\n"
        markdownBody += "```\n"
        markdownBody += "Name: \(newUserProfile.firstName ?? "") \(newUserProfile.lastName ?? "")\n"
        markdownBody += "Email: \(newUserProfile.email ?? "<missing email>")\n"
        markdownBody += "Admin Access: \(newUserAdminAccess ? "true" : "false")\n"
        markdownBody += "Corporate Access: \(newUserCorporateAccess ? "true" : "false")\n"
        markdownBody += "Team Level Access Count: \(newTeamCount)\n"
        markdownBody += "Property Level Access Count: \(newPropertyCount)\n"
        markdownBody += "```\n"
        markdownBody += "*Edited by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    
    // MARK: - TEAMS
    
    class func sendTeamCreation(newTeam: Team) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Team Creation"
        newNotification.summary = "\(newTeam.name ?? "<name missing>") created by \(editorShortName)"
        
        var markdownBody =  "```\n"
        markdownBody += "Name: \(newTeam.name ?? "<name missing>")\n"
        markdownBody += "```\n"
        markdownBody += "*Created by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendTeamUpdate(prevTeam: Team, newTeam: Team) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Team Update"
        newNotification.summary = "\(prevTeam.name ?? "<name missing>") updated to \(newTeam.name ?? "<name missing>") by \(editorShortName)"
        
        var markdownBody =  "Previous Data:\n"
        markdownBody += "```\n"
        markdownBody += "Name: \(prevTeam.name ?? "<name missing>")\n"
        markdownBody += "```\n"
        markdownBody +=  "New Data:\n"
        markdownBody += "```\n"
        markdownBody += "Name: \(newTeam.name ?? "<name missing>")\n"
        markdownBody += "```\n"
        markdownBody += "*Updated by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendTeamDeletion(team: Team) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Team Deletion"
        newNotification.summary = "\(team.name ?? "<name missing>") deleted by \(editorShortName)"
        
        var markdownBody =  "`Name: \(team.name ?? "<name missing>")`\n"
        markdownBody += "*Deleted by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    // MARK: - PROPERTIES
    
    class func sendPropertyCreation(newProperty: Property) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Property Creation"
        newNotification.summary = "\(newProperty.name ?? "<name missing>") created by \(editorShortName)"
        
        var markdownBody =  "```\n"
        markdownBody += "Name: \(newProperty.name ?? "<name missing>")\n"
        markdownBody += "```\n"
        markdownBody += "*Created by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    // TODO: Complete markdown
    class func sendPropertyUpdate(prevProperty: Property, newProperty: Property) {
        let notificationData = Notifications.notificationData()
        guard let _ = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Property Update"
        newNotification.summary = "\(newProperty.name ?? "<name missing>") updated by \(editorShortName)"
        
        newNotification.markdownBody = nil
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendPropertyDeletion(property: Property) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Property Deletion"
        newNotification.summary = "\(property.name ?? "<name missing>") deleted by \(editorShortName)"
        
        var markdownBody =  "`Name: \(property.name ?? "<name missing>")`\n"
        markdownBody += "*Deleted by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    // MARK: - TEMPLATES
    
    class func sendTemplateCreation(newTemplate: Template) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Template Creation"
        newNotification.summary = "\(newTemplate.name ?? "<name missing>") created by \(editorShortName)"
        
        var markdownBody =  "```\n"
        markdownBody += "Name: \(newTemplate.name ?? "<name missing>")\n"
        markdownBody += "Description: \(newTemplate.description ?? "<description missing>")\n"
        markdownBody += "```\n"
        markdownBody += "*Created by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    // TODO: Complete markdown
    class func sendTemplateUpdate(prevTemplate: Template, newTemplate: Template) {
        let notificationData = Notifications.notificationData()
        guard let _ = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Template Update"
        newNotification.summary = "\(newTemplate.name ?? "<name missing>") updated by \(editorShortName)"
        
        newNotification.markdownBody = nil
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendTemplateDeletion(template: Template) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Template Deletion"
        newNotification.summary = "\(template.name ?? "<name missing>") deleted by \(editorShortName)"
        
        var markdownBody =  "`Name: \(template.name ?? "<name missing>")`\n"
        markdownBody += "`Description: \(template.description ?? "<description missing>")`\n"
        markdownBody += "*Deleted by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    // MARK: - TEMPLATE CATEGORIES
    
    class func sendTemplateCategoryCreation(newTemplateCategory: TemplateCategory) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Template Category Creation"
        newNotification.summary = "\(newTemplateCategory.name ?? "<name missing>") created by \(editorShortName)"
        
        var markdownBody =  "```\n"
        markdownBody += "Name: \(newTemplateCategory.name ?? "<name missing>")\n"
        markdownBody += "```\n"
        markdownBody += "*Created by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendTemplateCategoryUpdate(prevTemplateCategory: TemplateCategory, newTemplateCategory: TemplateCategory) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Template Category Update"
        newNotification.summary = "\(prevTemplateCategory.name ?? "<name missing>") updated to \(newTemplateCategory.name ?? "<name missing>") by \(editorShortName)"
        
        var markdownBody =  "Previous Data:\n"
        markdownBody += "```\n"
        markdownBody += "Name: \(prevTemplateCategory.name ?? "<name missing>")\n"
        markdownBody += "```\n"
        markdownBody +=  "New Data:\n"
        markdownBody += "```\n"
        markdownBody += "Name: \(newTemplateCategory.name ?? "<name missing>")\n"
        markdownBody += "```\n"
        markdownBody += "*Updated by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendTemplateCategoryDeletion(templateCategory: TemplateCategory) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Template Category Deletion"
        newNotification.summary = "\(templateCategory.name ?? "<name missing>") deleted by \(editorShortName)"
        
        var markdownBody =  "`Name: \(templateCategory.name ?? "<name missing>")`\n"
        markdownBody += "*Deleted by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendJobDeletion(job: Job) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Job Deletion"
        newNotification.summary = "\(job.title ?? "<title missing>") deleted by \(editorShortName)"
        
        var markdownBody =  "`Title: \(job.title ?? "<title missing>")`\n"
        markdownBody += "*Deleted by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendBidDeletion(bid: Bid) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Job Bid Deletion"
        newNotification.summary = "\(bid.vendor ?? "<vendor missing>") deleted by \(editorShortName)"
        
        var markdownBody =  "`Vendor: \(bid.vendor ?? "<vendor missing>")`\n"
        markdownBody += "*Deleted by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }

    // MARK: - TRELLO INTEGRATION

    class func sendTrelloIntegrationAddition(organizationTrello: OrganizationTrello) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Trello Integration Added"
        newNotification.summary = "The trello account \(organizationTrello.trelloFullName ?? "<name missing>") (@\(organizationTrello.trelloUsername)) added by \(editorShortName)"
        
        var markdownBody =  "```\n"
        markdownBody += "Name: \(organizationTrello.trelloFullName ?? "<name missing>")\n"
        markdownBody += "Username: \(organizationTrello.trelloUsername)\n"
        markdownBody += "```\n"
        markdownBody += "*Added by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendTrelloIntegrationDeletion(organizationTrello: OrganizationTrello) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Trello Integration Removed"
        newNotification.summary = "The trello account \(organizationTrello.trelloFullName ?? "<name missing>") (@\(organizationTrello.trelloUsername)) removed by \(editorShortName)"

        var markdownBody =  "`Name: \(organizationTrello.trelloFullName ?? "<name missing>")`\n"
        markdownBody += "`Username: \(organizationTrello.trelloUsername)`\n"
        markdownBody += "*Removed by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    // MARK: - SLACK INTEGRATION

    // Not used, data missing
    class func sendSlackIntegrationAddition(organizationSlack: OrganizationSlack) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Slack App Addition"
        newNotification.summary = "The Sparkle Slack App added to team \(organizationSlack.teamName ?? "<name missing>") by \(editorShortName)"
        
        var markdownBody =  "```\n"
        markdownBody += "Slack Team: \(organizationSlack.teamName ?? "<name missing>")\n"
        markdownBody += "```\n"
        markdownBody += "*Added by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendSlackIntegrationDeletion(organizationSlack: OrganizationSlack) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + "Slack App Removed"
        newNotification.summary = "The Sparkle Slack App removed for team \(organizationSlack.teamName ?? "<name missing>") by \(editorShortName)"
        
        var markdownBody =  "```\n"
        markdownBody += "Slack Team: \(organizationSlack.teamName ?? "<name missing>")\n"
        markdownBody += "```\n"
        markdownBody += "*Removed by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendSlackIntegrationSystemChannelUpdate(channelName: String) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        newNotification.title = Notifications.env() + "Slack App Update"
        newNotification.summary = "System Channel updated to \(channelName) by \(editorShortName)"
        
        var markdownBody =  "```\n"
        markdownBody += "System Channel: \(channelName)\n"
        markdownBody += "```\n"
        markdownBody += "*Updated by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    // MARK: - PROPERTY: Inspections

    class func sendPropertyInspectionCompleted(keyProperty: KeyProperty, keyInspection: keyInspection) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.short
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "MMM dd"
        var creationDateString = "<date missing>"
        var creationShortDateString = "<date missing>"
        if let creationDate = keyInspection.inspection.creationDate {
            creationDateString = formatter.string(from: creationDate)
            creationShortDateString = shortFormatter.string(from: creationDate)
        }
        var templateName = "<name missing>"
        var trackDeficientItems = false
        var numOfDeficientItems = 0
        if let template = Mapper<Template>().map(JSON: keyInspection.inspection.template ?? [:]) {
            if let name = template.name {
                templateName = name
            }
            trackDeficientItems = template.trackDeficientItems
            if trackDeficientItems {
                if let items = template.items {
                    for item in items {
                        if let templateItem = Mapper<TemplateItem>().map(JSONObject: item.value), templateItem.isDeficientItem {
                            numOfDeficientItems += 1
                        }
                    }
                }
            }
        }
        newNotification.title = Notifications.env() + (keyProperty.property.name ?? "Unknown Property")
        newNotification.summary = "\(creationShortDateString) inspection completed by \(editorShortName), using \(templateName) template"
        
        var markdownBody =  "*Inspection Completion*\n"
        markdownBody += "```\n"
        markdownBody += "Template: \(templateName)\n"
        markdownBody += "Inspection Start Date: \(creationDateString)\n"
        markdownBody += "Score: \(String(format:"%.1f", keyInspection.inspection.score) + "%")\n"
        if trackDeficientItems {
            markdownBody += "# of deficient items: \(numOfDeficientItems)\n"
        }
        markdownBody += "```\n"
        if let property = keyInspection.inspection.property {
            markdownBody += "*Inspection*: \(webAppBaseURL)/properties/\(property)/update-inspection/\(keyInspection.key)\n"
        }
        markdownBody += "*Completed by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        newNotification.property = keyProperty.key
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendPropertyInspectionReportCreated(keyProperty: KeyProperty, keyInspection: keyInspection, isFirstReport: Bool) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.short
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "MMM dd"
        var creationDateString = "<date missing>"
        var creationShortDateString = "<date missing>"
        if let creationDate = keyInspection.inspection.creationDate {
            creationDateString = formatter.string(from: creationDate)
            creationShortDateString = shortFormatter.string(from: creationDate)
        }
        var completionDateString = "<date missing>"
        if let completionDate = keyInspection.inspection.completionDate {
            completionDateString = formatter.string(from: completionDate)
        }
        var templateName = "<name missing>"
        var trackDeficientItems = false
        var numOfDeficientItems = 0
        if let template = Mapper<Template>().map(JSON: keyInspection.inspection.template ?? [:]) {
            if let name = template.name {
                templateName = name
            }
            trackDeficientItems = template.trackDeficientItems
            if trackDeficientItems {
                if let items = template.items {
                    for item in items {
                        if let templateItem = Mapper<TemplateItem>().map(JSONObject: item.value), templateItem.isDeficientItem {
                            numOfDeficientItems += 1
                        }
                    }
                }
            }
        }
        newNotification.title = Notifications.env() + (keyProperty.property.name ?? "Unknown Property")
        if isFirstReport {
            newNotification.summary = "\(creationShortDateString) inspection report created by \(editorShortName)"
        } else {
            newNotification.summary = "\(creationShortDateString) inspection report updated by \(editorShortName)"
        }
        
        var markdownBody = "*Inspection Report Creation*\n"
        if !isFirstReport {
            markdownBody = "*Inspection Report Update*\n"
        }
        markdownBody += "```\n"
        markdownBody += "Template: \(templateName)\n"
        markdownBody += "Inspection Start Date: \(creationDateString)\n"
        markdownBody += "Inspection Completion Date: \(completionDateString)\n"
        markdownBody += "```\n"
        if let property = keyInspection.inspection.property {
            markdownBody += "*Inspection*: \(webAppBaseURL)/properties/\(property)/update-inspection/\(keyInspection.key)\n\n"
        }
        if let urlString = keyInspection.inspection.inspectionReportURL {
            markdownBody += "*Inspection Report*: \(urlString)\n"
        }
        if isFirstReport {
            markdownBody += "*Created by*: \(editor)"
        } else {
            markdownBody += "*Updated by*: \(editor)"
        }
        newNotification.markdownBody = markdownBody
        
        newNotification.property = keyProperty.key
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendPropertyInspectionDeletion(keyProperty: KeyProperty, keyInspection: keyInspection) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.short
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "MMM dd"
        var creationDateString = "<date missing>"
        var creationShortDateString = "<date missing>"
        if let creationDate = keyInspection.inspection.creationDate {
            creationDateString = formatter.string(from: creationDate)
            creationShortDateString = shortFormatter.string(from: creationDate)
        }
        var templateName = "<name missing>"
        if let name = keyInspection.inspection.templateName {
            templateName = name
        }
        newNotification.title = Notifications.env() + (keyProperty.property.name ?? "Unknown Property")
        newNotification.summary = "\(creationShortDateString) inspection deleted by \(editorShortName)"
        
        var markdownBody = "*Inspection Deletion*\n"
        markdownBody += "`Inspection created on \(creationDateString), with template: \(templateName)`\n"
        markdownBody += "*Deleted by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        newNotification.property = keyProperty.key
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    // MARK: - PROPERTY: Deficient Items
    
    class func sendPropertyDeficientItemStateChange(keyProperty: KeyProperty, keyInspectionDeficientItem: keyInspectionDeficientItem, prevState: String) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.short
        
        let newState = keyInspectionDeficientItem.item.state ?? "<state missing>"

        newNotification.title = Notifications.env() + (keyProperty.property.name ?? "Unknown Property")
        if prevState == newState {
            newNotification.summary = "Deficient Item: \(keyInspectionDeficientItem.item.itemTitle) updated by \(editorShortName)"
        } else {
            newNotification.summary = "Deficient Item: \(keyInspectionDeficientItem.item.itemTitle) moved from \(prevState) to \(newState) by \(editorShortName)"
        }
        
        var markdownBody =  "Deficient Item moved from *\(prevState)* to *\(newState)*\n"
        if prevState == newState {
            markdownBody =  "*Deficient Item Update*\n"
        }
        markdownBody +=  "```\n"
        markdownBody += "Title: \(keyInspectionDeficientItem.item.itemTitle)\n"
        markdownBody += "Section: \(keyInspectionDeficientItem.item.sectionTitle)\n"
        if let subSection = keyInspectionDeficientItem.item.sectionSubtitle {
            markdownBody += "Sub-Section: \(subSection)\n"
        }
        if keyInspectionDeficientItem.item.state == InspectionDeficientItemState.deferred.rawValue {
            if let currentDeferredDateDay = keyInspectionDeficientItem.item.currentDeferredDateDay {
                markdownBody += "Deferred Date: \(currentDeferredDateDay)\n"
            } else if let currentDeferredDate = keyInspectionDeficientItem.item.currentDeferredDate {
                markdownBody += "Deferred Date: \(formatter.string(from: currentDeferredDate))"
            }
        } else {
            if let currentDueDateDay = keyInspectionDeficientItem.item.currentDueDateDay {
                markdownBody += "Due Date: \(currentDueDateDay)\n"
            } else if let currentDueDate = keyInspectionDeficientItem.item.currentDueDate {
                markdownBody += "Due Date: \(formatter.string(from: currentDueDate))"
            }
        }
        if let planToFix = keyInspectionDeficientItem.item.currentPlanToFix {
            markdownBody += "Plan to fix: \(planToFix)\n"
        }
        if let responsibilityGroup = keyInspectionDeficientItem.item.currentResponsibilityGroup {
            markdownBody += "Responsibility Group: \(responsibilityGroup)\n"
        }
        if keyInspectionDeficientItem.item.isDuplicate {
            markdownBody += "Duplicate?: YES\n"
        }
        markdownBody += "```\n"

        if let dict = keyInspectionDeficientItem.item.progressNotes {
            let json = JSON(dict).dictionaryValue
            var progressNotes:[JSON] = []
            for valueJSON in json.values {
                progressNotes.append(valueJSON)
            }
            
            // Sort
            progressNotes.sort(by: { (first, second) -> Bool in
                let firstCreatedAt = first["createdAt"].doubleValue
                let secondCreatedAt = second["createdAt"].doubleValue
                return firstCreatedAt > secondCreatedAt
            })
            
            if let latestProgressNote = progressNotes.first, let note = latestProgressNote["progressNote"].string, let createdAt = latestProgressNote["createdAt"].double {
                let createdAtDate = Date(timeIntervalSince1970: createdAt)
                markdownBody += "```\n"
                markdownBody += "Progress Note (\(formatter.string(from: createdAtDate))): \(note)\n"
                markdownBody += "```\n"
            }
        }
        if let completeNowReason = keyInspectionDeficientItem.item.currentCompleteNowReason {
            markdownBody += "```\n"
            markdownBody += "Complete Now Reason: \(completeNowReason)\n"
            markdownBody += "```\n"
        }
        if let currentReasonIncomplete = keyInspectionDeficientItem.item.currentReasonIncomplete {
            markdownBody += "```\n"
            markdownBody += "Reason Incomplete: \(currentReasonIncomplete)\n"
            markdownBody += "```\n"
        }
        
        
        markdownBody += "*Deficient Item*: \(webAppBaseURL)/properties/\(keyProperty.key)/deficient-items/\(keyInspectionDeficientItem.key)\n\n"

        if let trelloCardURL = keyInspectionDeficientItem.item.trelloCardURL {
            markdownBody += "*Trello Card*: \(trelloCardURL)\n\n"
        }
        
        markdownBody += "*Updated by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        newNotification.property = keyProperty.key
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendPropertyDeficientItemTrelloCardCreation(keyProperty: KeyProperty, keyInspectionDeficientItem: keyInspectionDeficientItem) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + (keyProperty.property.name ?? "Unknown Property")
        newNotification.summary = "Trello Card created for Deficient Item: \(keyInspectionDeficientItem.item.itemTitle) by \(editorShortName)"
        
        var markdownBody =  "*Trello Card created for Deficient Item*\n"

        markdownBody +=  "```\n"
        markdownBody += "Title: \(keyInspectionDeficientItem.item.itemTitle)\n"
        markdownBody += "Section: \(keyInspectionDeficientItem.item.sectionTitle)\n"
        if let subSection = keyInspectionDeficientItem.item.sectionSubtitle {
            markdownBody += "Sub-Section: \(subSection)\n"
        }
        markdownBody += "```\n"
        
        markdownBody += "*Deficient Item*: \(webAppBaseURL)/properties/\(keyProperty.key)/deficient-items/\(keyInspectionDeficientItem.key)\n\n"
        
        if let trelloCardURL = keyInspectionDeficientItem.item.trelloCardURL {
            markdownBody += "*Trello Card*: \(trelloCardURL)\n\n"
        }
        
        markdownBody += "*Created by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        newNotification.property = keyProperty.key
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }
    
    class func sendPropertyTrelloSettingsUpdate(keyProperty: KeyProperty, prevKeyPropertyTrello: (key: String, propertyTrello: PropertyTrello?), keyPropertyTrello: (key: String, propertyTrello: PropertyTrello?)) {
        let notificationData = Notifications.notificationData()
        guard let editor = notificationData.editor, let editorShortName = notificationData.editorShortName, let newNotification = notificationData.newNotification else {
            return
        }
        
        newNotification.title = Notifications.env() + (keyProperty.property.name ?? "Unknown Property")
        newNotification.summary = "Trello Settings updated by \(editorShortName)"
        
        var markdownBody =  "*Trello Settings updated*\n"
        
        markdownBody +=  "Previous Settings\n"
        markdownBody +=  "```\n"
        markdownBody += "Deficient Items, OPEN Board: \(prevKeyPropertyTrello.propertyTrello?.openBoardName ?? "NOT SET")\n"
        markdownBody += "Deficient Items, OPEN List: \(prevKeyPropertyTrello.propertyTrello?.openListName ?? "NOT SET")\n"
        markdownBody += "Deficient Items, CLOSED Board: \(prevKeyPropertyTrello.propertyTrello?.closedBoardName ?? "NOT SET")\n"
        markdownBody += "Deficient Items, CLOSED List: \(prevKeyPropertyTrello.propertyTrello?.closedListName ?? "NOT SET")\n"
        markdownBody += "```\n"
        markdownBody +=  "New Settings\n"
        markdownBody +=  "```\n"
        markdownBody += "Deficient Items, OPEN Board: \(keyPropertyTrello.propertyTrello?.openBoardName ?? "NOT SET")\n"
        markdownBody += "Deficient Items, OPEN List: \(keyPropertyTrello.propertyTrello?.openListName ?? "NOT SET")\n"
        markdownBody += "Deficient Items, CLOSED Board: \(keyPropertyTrello.propertyTrello?.closedBoardName ?? "NOT SET")\n"
        markdownBody += "Deficient Items, CLOSED List: \(keyPropertyTrello.propertyTrello?.closedListName ?? "NOT SET")\n"
        markdownBody += "```\n"
        
        markdownBody += "*Updated by*: \(editor)"
        newNotification.markdownBody = markdownBody
        
        newNotification.property = keyProperty.key
        
        dbCollectionNotifications().addDocument(data: newNotification.toJSON())
    }

}
