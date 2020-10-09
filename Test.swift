//
//  Test.swift
//  CombineFormViewModel
//
//  Created by Spencer Prescott on 10/8/20.
//

import SwiftUI

class TestViewModel: ObservableObject {
    @Published var item: String = "Hi"
}

struct Test: View {
    let viewModel: TestViewModel

    var body: some View {
        NavigationLink(
            destination: /*@START_MENU_TOKEN@*/Text("Destination")/*@END_MENU_TOKEN@*/,
            label: {
                /*@START_MENU_TOKEN@*/Text("Navigate")/*@END_MENU_TOKEN@*/
            })
    }
}

struct Test_Previews: PreviewProvider {
    static var previews: some View {
        Test(viewModel: .init())
    }
}
