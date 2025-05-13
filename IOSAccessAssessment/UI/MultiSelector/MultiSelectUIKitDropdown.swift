//
//  MultiSelectUIKit.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/13/25.
//

//import SwiftUI
//import RSSelectionMenu
//
//struct MultiSelectUIKitDropdown: UIViewControllerRepresentable {
//    let options: [String]
//    @Binding var selected: [String]
//
//    func makeUIViewController(context: Context) -> UIViewController {
//        let vc = UIViewController()
//
//        let menu = RSSelectionMenu(selectionStyle: .multiple, dataSource: options) { (cell, item, isSelected) in
//            cell.textLabel?.text = item
//        }
//
//        menu.setSelectedItems(items: selected)
//
//        menu.onDismiss = { selectedItems in
//            selected = selectedItems
//        }
//
//        menu.show(style: .popover(sourceView: vc.view, size: CGSize(width: 250, height: 300)), from: vc)
//
//        return vc
//    }
//
//    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
//}
