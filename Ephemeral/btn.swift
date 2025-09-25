//
//  btn.swift
//  Ephemeral
//
//  Created by Federica Ziaco on 25/09/25.
//

import SwiftUI
struct btn: View {
    var body: some View{
        VStack {
            Button(action: {
            }) {
                Text("Restart Experience")
                    .font(.headline)
                    .padding()
                    .frame(width: 200)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 8)
            }
        }
        
    }



}

#Preview {
    btn()
}
