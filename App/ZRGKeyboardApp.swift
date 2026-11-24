import SwiftUI

@main
struct ZRGKeyboardApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var text = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("ZRG Keyboard").font(.largeTitle).bold()
                Text("Clavier AZERTY normal : chaque lettre tapée apparaît dans un style différent et aléatoire.")
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Activation").font(.headline)
                    Text("1. Réglages › Général › Clavier › Claviers › Ajouter un clavier…")
                    Text("2. Choisis « ZRG Keyboard » dans la liste.")
                    Text("3. Dans n'importe quel champ de texte, maintiens 🌐 et choisis ZRG Keyboard.")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Option (touche à gauche de l'espace)").font(.headline)
                    Text("🎲  →  lettres stylisées aléatoires")
                    Text("Aa  →  désactivé, texte normal")
                }

                Button("Ouvrir les Réglages") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .padding(.vertical, 6)

                Text("Zone de test").font(.headline)
                TextField("Écris ici…", text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
        }
    }
}
