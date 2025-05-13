//
//  MultiSelector.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/12/25.
//

import SwiftUI

struct MultiSelector<LabelView: View, Selectable: Identifiable & Hashable>: View {
    let label: LabelView
    let options: [Selectable]
    let optionToString: (Selectable) -> String

    var selected: Binding<Set<Selectable>>

    private var formattedSelectedListString: String {
        ListFormatter.localizedString(byJoining: selected.wrappedValue.map { optionToString($0) })
    }

    var body: some View {
        NavigationLink(destination: multiSelectionView()) {
            HStack {
                label
                Spacer()
                Text(formattedSelectedListString)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func multiSelectionView() -> some View {
        MultiSelectionView(
            options: options,
            optionToString: optionToString,
            selected: selected
        )
    }
}

//struct MultiSelector_Previews: PreviewProvider {
//    struct IdentifiableString: Identifiable, Hashable {
//        let string: String
//        var id: String { string }
//    }
//
//    @State static var selected: Set<IdentifiableString> = Set(["A", "C"].map { IdentifiableString(string: $0) })
//
//    static var previews: some View {
//        NavigationView {
//            Form {
//                MultiSelector<Text, IdentifiableString>(
//                    label: Text("Multiselect"),
//                    options: ["A", "B", "C", "D"].map { IdentifiableString(string: $0) },
//                    optionToString: { $0.string },
//                    selected: $selected
//                )
//            }.navigationTitle("Title")
//        }
//    }
//}

struct IngredientsPickerView: View {
    @State var ingredients: [Ingredient] = [
        Ingredient(name:"Salt"),
        Ingredient(name:"Pepper"),
        Ingredient(name:"Chili"),
        Ingredient(name:"Milk")
    ]
    
    var body: some View{
        List{
            ForEach(0..<ingredients.count){ index in
                HStack {
                    Button(action: {
                        ingredients[index].isSelected = ingredients[index].isSelected ? false : true
                    }) {
                        HStack{
                            if ingredients[index].isSelected {
                                Image(systemName:"checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .animation(.easeIn)
                            } else {
                                Image(systemName:"circle")																		.foregroundColor(.primary)
                                    .animation(.easeOut)
                            }
                            Text(ingredients[index].name)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
        }
    }
}
struct Ingredient{
    var id = UUID()
    var name: String
    var isSelected: Bool = false
}
