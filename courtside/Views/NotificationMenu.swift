import SwiftUI

struct NotificationMenu: View {
    var width: CGFloat = 250
    var isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Placeholder for notifications.
            // Future functionality: Populate with notifications from a database.
            Text("No notifications currently")
                .padding()
            Spacer()
        }
        .frame(width: width, alignment: .leading)
        .background(Color(UIColor.systemGray6))
        .offset(x: isOpen ? 0 : width)
        .animation(.easeInOut, value: isOpen)
//        .edgesIgnoringSafeArea(.vertical)
    }
}

struct NotificationMenu_Previews: PreviewProvider {
    static var previews: some View {
        NotificationMenu(isOpen: true)
    }
}
    