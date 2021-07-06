//
//  SupportDocsView.swift
//  SupportDocsSwiftUI
//
//  Created by Zheng on 10/12/20.
//

import SwiftUI

public struct SupportDocsView: View {
    
    /**
     Instantiate SupportDocs in your app.
     
     - parameter dataSourceURL: URL of the JSON file, where SupportDocs gets its data. This is generated by the GitHub Action.
     - parameter options: Options used for configuring SupportDocs. This is optional (mostly for changing the SupportDocs' appearance).
     - parameter isPresented: The Binding that you use to present SupportDocs in SwiftUI. Required if you want a "Dismiss" button.
     
     If you want to have a "Dismiss" button, you must also pass in the `@State` property that you use for the `.sheet`, like this:
     
     ```
     struct SwiftUIExampleView_MinimalCode: View {
         let dataSource = URL(string: "https://raw.githubusercontent.com/aheze/SupportDocs/DataSource/_data/supportdocs_datasource.json")!
         @State var supportDocsPresented = false
         
         var body: some View {
             Button("Present SupportDocs from SwiftUI!") { supportDocsPresented = true }
             .sheet(isPresented: $supportDocsPresented, content: {
     
                     /// pass it in...                       ...here:
                 SupportDocsView(dataSourceURL: dataSource, isPresented: $supportDocsPresented)
             })
         }
     }

     ```
     This is only for SwiftUI -- You don't need to do this in UIKit. As long as you set `options.navigationBar.dismissButtonTitle = "Dismiss"`, SupportDocs will dismiss itself.
     */
    public init(dataSourceURL: URL, options: SupportOptions = SupportOptions(), isPresented: Binding<Bool>? = nil) {
        self.dataSourceURL = dataSourceURL
        self.options = options
        self.isPresented = isPresented
    }
    
    /**
     URL of the JSON file, where SupportDocs gets its data. This is generated by the GitHub Action.
     
     An example file can be found [here](https://raw.githubusercontent.com/aheze/SupportDocs/DataSource/_data/supportdocs_datasource.json).
    */
    public let dataSourceURL: URL
    
    /**
     Options used for configuring SupportDocs. This is optional (mostly for changing the SupportDocs' appearance).
     */
    public var options: SupportOptions = SupportOptions()
    
    /**
     The Binding that you use to present SupportDocs in SwiftUI. Required if you want a "Done" button.
     
     Pass in the `@State` property that you use for the `.sheet`, like this:
     
     ```
     struct SwiftUIExampleView_MinimalCode: View {
         let dataSource = URL(string: "https://raw.githubusercontent.com/aheze/SupportDocs/DataSource/_data/supportdocs_datasource.json")!
         @State var supportDocsPresented = false
         
         var body: some View {
             Button("Present SupportDocs from SwiftUI!") { supportDocsPresented = true }
             .sheet(isPresented: $supportDocsPresented, content: {
     
                     /// pass it in...                       ...here:
                 SupportDocsView(dataSourceURL: dataSource, isPresented: $supportDocsPresented)
             })
         }
     }
     ```
     This is only for SwiftUI -- You don't need to do this in UIKit. As long as you set `options.navigationBar.dismissButtonTitle = "Dismiss"`, SupportDocs will dismiss itself.
     */
    public var isPresented: Binding<Bool>? = nil
    
    /**
     The dismiss button handler for UIKit. This is automatically passed in by `SupportDocsViewController`, you don't access this property.
     */
    internal var donePressed: (() -> Void)?
    
    /**
     The documents decoded from the JSON.
     */
    @State internal var documents: [JSONSupportDocument] = [JSONSupportDocument]()
    
    /**
     If the JSON is downloading, display the loading spinner.
     */
    @State internal var isDownloadingJSON = true
    
    /**
     The data from the JSON is sorted into this, based on how you configured `options.categories`. The list that displays your documents' titles gets it data from here.
     */
    @State internal var sections: [SupportSection] = [SupportSection]()
    
    /**
     Reference of the search bar and its delegate.
     */
    @ObservedObject var searchBarConfigurator = SearchBarConfigurator()
    
    public var body: some View {
        NavigationView {
            ZStack {
                if isDownloadingJSON {
                    
                    /// Show the loading spinner if JSON is downloading.
                    ActivityIndicator(isAnimating: $isDownloadingJSON, style: options.other.activityIndicatorStyle)
                } else {
                    
                    List {
                        
                        /// First, display the titles of your documents.
                        ForEach(
                            
                            /// Filter the sections. Display only those that contain documents where their titles contain the search bar's text.
                            sections.filter { section in
                                return searchBarConfigurator.searchText.isEmpty || section.supportItems.contains(where: {
                                    $0.title.localizedStandardContains(searchBarConfigurator.searchText)
                                })
                            }
                        ) { section in
                            Section(header: Text(section.name)) {
                                ForEach(
                                    
                                    /// Filter the documents in each section.
                                    section.supportItems.filter { item in
                                        return searchBarConfigurator.searchText.isEmpty || item.title.localizedStandardContains(searchBarConfigurator.searchText)
                                    }
                                ) { item in
                                    SupportItemRow(
                                        title: item.title,
                                        titleColor: section.color,
                                        url: URL(string: item.url) ?? options.other.error404,
                                        progressBarOptions: options.progressBar
                                    )
                                    .animation(nil)
                                }
                            }
                            .displayTextAsConfigured() /// Prevent default all-caps behavior if possible (iOS 14 and above).
                        }
                        
                        /// Then, display the footer. Customize this inside `options.other.footer`.
                        options.other.footer
                            .listRowInsets(EdgeInsets())
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(Color(UIColor.systemGroupedBackground))
                        
                    }
                    .listStyle(for: options.listStyle) /// Set the `listStyle` of your selection.
                    .transition(.opacity) /// Fade the List in once the JSON loads.
                    
                }
            }
            .navigationBarTitle(Text(options.navigationBar.title), displayMode: .large) /// Set your title.
            .configureBar(for: options, searchBarConfigurator: searchBarConfigurator)
            
            /**
             If you have a dismiss button, display it.
             */
            .ifConditional( /// Helper inside `Utilities.swift`.
                options.navigationBar.dismissButtonView != nil
                    &&
                (isPresented != nil || donePressed != nil)
            ) { content in
                content.navigationBarItems(
                    trailing:
                        Button(action: {
                            /**
                             When the dismiss button is pressed, dismiss SupportDocs.
                             */
                            isPresented?.wrappedValue = false /// if presented with SwiftUI, toggle the `Binding` that presented this in a sheet.
                            donePressed?() /// if presented with UIKit, trigger the done handler.
                        }) {
                            options.navigationBar.dismissButtonView
                        }
                )
            }
            
            /**
             Show the welcome view if in landscape or on iPad, when a row hasn't been selected yet.
             */
            options.other.welcomeView
        }
        .navigationViewStyle(for: options.navigationViewStyle, customListStyle: options.listStyle) /// Set the `navigationViewStyle` of your selection.
        
        /**
         When everything first loads, load the JSON.
         */
        .onAppear {
            loadData()
        }
    }
}