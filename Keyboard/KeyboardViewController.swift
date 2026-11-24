import UIKit

// MARK: - Styles Unicode aléatoires

/// iOS ne permet pas à un clavier d'imposer une police au texte envoyé.
/// On transforme donc chaque lettre tapée en caractère Unicode "stylisé"
/// (gras, script, fraktur, cerclé, carré, pleine largeur, monospace…) : le style est
/// réellement dans le texte, il s'affiche donc dans n'importe quelle appli.
enum Styler {
    // (début des majuscules, début des minuscules — nil = mêmes glyphes pour les deux)
    private static let styles: [(UInt32, UInt32?)] = [
        (0x1D400, 0x1D41A), // gras
        (0x1D468, 0x1D482), // gras italique
        (0x1D4D0, 0x1D4EA), // script gras
        (0x1D56C, 0x1D586), // fraktur gras
        (0x1D5A0, 0x1D5BA), // sans
        (0x1D5D4, 0x1D5EE), // sans gras
        (0x1D608, 0x1D622), // sans italique
        (0x1D63C, 0x1D656), // sans gras italique
        (0x1D670, 0x1D68A), // monospace
        (0x24B6,  0x24D0),  // cerclé
        (0x1F150, nil),     // cerclé noir
        (0x1F130, nil),     // carré
        (0x1F170, nil),     // carré noir
        (0xFF21,  0xFF41),  // pleine largeur
    ]

    private static var last = -1

    static func apply(_ s: String) -> String {
        guard let u = s.unicodeScalars.first, s.unicodeScalars.count == 1 else { return s }
        let v = u.value
        let isUpper = (65...90).contains(v), isLower = (97...122).contains(v)
        guard isUpper || isLower else { return s }

        var i = Int.random(in: 0..<styles.count)
        if i == last { i = (i + 1 + Int.random(in: 0..<(styles.count - 1))) % styles.count } // jamais 2 fois le même d'affilée
        last = i

        let (up, low) = styles[i]
        let base: UInt32 = isUpper ? up : (low ?? up)
        let idx = isUpper ? v - 65 : v - 97
        guard let scalar = Unicode.Scalar(base + idx) else { return s }
        return String(Character(scalar))
    }
}

// MARK: - Mode

enum StyleMode: Int {
    case off = 0, on = 1
    var next: StyleMode { self == .off ? .on : .off }
    var icon: String { self == .off ? "Aa" : "🎲" }

    static var saved: StyleMode {
        get {
            if UserDefaults.standard.object(forKey: "styleMode") == nil { return .on }
            return StyleMode(rawValue: UserDefaults.standard.integer(forKey: "styleMode")) ?? .on
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "styleMode") }
    }
}

// MARK: - Touche

final class Key: UIButton {
    var value: String = ""
}

// MARK: - Contrôleur

final class KeyboardViewController: UIInputViewController {

    private enum Page { case letters, symbols }
    private enum Shift { case off, once, caps }

    private var page: Page = .letters
    private var shift: Shift = .off
    private var mode: StyleMode = StyleMode.saved
    private var lastShiftTap = Date.distantPast

    private var letterKeys: [Key] = []
    private var modeKey: Key?
    private var shiftKey: Key?
    private let container = UIStackView()
    private var deleteTimer: Timer?
    private var deleteDelay: Timer?

    // Pour du QWERTY : "qwertyuiop", "asdfghjkl", "zxcvbnm"
    private let lettersRows = ["azertyuiop", "qsdfghjklm", "wxcvbn"]
    private let symbolsRows = ["1234567890", "-/:;()€&@\"", ".,?!'%+="]

    override func viewDidLoad() {
        super.viewDidLoad()
        let h = view.heightAnchor.constraint(equalToConstant: 226)
        h.priority = UILayoutPriority(999)
        h.isActive = true

        container.axis = .vertical
        container.spacing = 8
        container.distribution = .fillEqually
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
        ])
        build()
    }

    // MARK: Construction

    private func build() {
        container.arrangedSubviews.forEach { $0.removeFromSuperview() }
        letterKeys.removeAll()
        let rows = page == .letters ? lettersRows : symbolsRows

        container.addArrangedSubview(makeLetterRow(rows[0]))
        container.addArrangedSubview(makeLetterRow(rows[1]))

        let row3 = UIStackView()
        row3.spacing = 6
        row3.distribution = .fill
        var left: Key?
        if page == .letters {
            let s = makeSpecial("⇧", dark: true)
            s.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
            shiftKey = s
            row3.addArrangedSubview(s)
            left = s
        }
        let letters = rows[2].map { makeLetter(String($0)) }
        letters.forEach { row3.addArrangedSubview($0) }
        for l in letters.dropFirst() { l.widthAnchor.constraint(equalTo: letters[0].widthAnchor).isActive = true }

        let del = makeSpecial("⌫", dark: true)
        del.addTarget(self, action: #selector(deleteDown), for: .touchDown)
        del.addTarget(self, action: #selector(deleteUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        row3.addArrangedSubview(del)
        del.widthAnchor.constraint(equalTo: row3.widthAnchor, multiplier: 0.13).isActive = true
        left?.widthAnchor.constraint(equalTo: row3.widthAnchor, multiplier: 0.13).isActive = true
        container.addArrangedSubview(row3)

        let bottom = UIStackView()
        bottom.spacing = 6
        bottom.distribution = .fill

        let pageKey = makeSpecial(page == .letters ? "123" : "ABC", dark: true)
        pageKey.addTarget(self, action: #selector(pageTapped), for: .touchUpInside)

        let globe = makeSpecial("🌐", dark: true)
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        let mk = makeSpecial(mode.icon, dark: true)
        mk.addTarget(self, action: #selector(modeTapped), for: .touchUpInside)
        modeKey = mk

        let space = makeSpecial("espace", dark: false)
        space.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)

        let ret = makeSpecial("↵", dark: true)
        ret.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)

        [pageKey, globe, mk, space, ret].forEach { bottom.addArrangedSubview($0) }
        pageKey.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.13).isActive = true
        globe.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.11).isActive = true
        mk.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.11).isActive = true
        ret.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.17).isActive = true
        container.addArrangedSubview(bottom)

        refreshLabels()
    }

    private func makeLetterRow(_ chars: String) -> UIStackView {
        let row = UIStackView()
        row.spacing = 6
        row.distribution = .fillEqually
        chars.forEach { row.addArrangedSubview(makeLetter(String($0))) }
        return row
    }

    private func style(_ k: Key, dark: Bool) {
        k.backgroundColor = UIColor { t in
            if t.userInterfaceStyle == .dark {
                return dark ? UIColor(white: 0.20, alpha: 1) : UIColor(white: 0.40, alpha: 1)
            }
            return dark ? UIColor(red: 0.67, green: 0.70, blue: 0.74, alpha: 1) : .white
        }
        k.setTitleColor(.label, for: .normal)
        k.layer.cornerRadius = 5
        k.layer.shadowColor = UIColor.black.cgColor
        k.layer.shadowOpacity = 0.35
        k.layer.shadowRadius = 0
        k.layer.shadowOffset = CGSize(width: 0, height: 1)
        k.titleLabel?.adjustsFontSizeToFitWidth = true
        k.titleLabel?.minimumScaleFactor = 0.5
    }

    private func makeLetter(_ c: String) -> Key {
        let k = Key(type: .custom)
        k.value = c
        style(k, dark: false)
        k.titleLabel?.font = .systemFont(ofSize: 22)
        k.addTarget(self, action: #selector(letterTapped(_:)), for: .touchDown)
        letterKeys.append(k)
        return k
    }

    private func makeSpecial(_ title: String, dark: Bool) -> Key {
        let k = Key(type: .custom)
        style(k, dark: dark)
        k.setTitle(title, for: .normal)
        k.titleLabel?.font = .systemFont(ofSize: 17)
        return k
    }

    // Les touches restent toujours normales ; seul le texte inséré est stylisé.
    private func refreshLabels() {
        let upper = (page == .letters && shift != .off)
        for k in letterKeys { k.setTitle(upper ? k.value.uppercased() : k.value, for: .normal) }
        modeKey?.setTitle(mode.icon, for: .normal)
        shiftKey?.setTitle(shift == .caps ? "⇪" : "⇧", for: .normal)
        shiftKey?.alpha = shift == .off ? 0.8 : 1.0
    }

    // MARK: Actions

    @objc private func letterTapped(_ k: Key) {
        var out = (page == .letters && shift != .off) ? k.value.uppercased() : k.value
        if mode == .on { out = Styler.apply(out) }
        textDocumentProxy.insertText(out)
        if shift == .once { shift = .off; refreshLabels() }
    }

    @objc private func shiftTapped() {
        let now = Date()
        if now.timeIntervalSince(lastShiftTap) < 0.35 { shift = .caps }
        else { shift = (shift == .off) ? .once : .off }
        lastShiftTap = now
        refreshLabels()
    }

    @objc private func pageTapped() {
        page = (page == .letters) ? .symbols : .letters
        shift = .off
        build()
    }

    @objc private func modeTapped() {
        mode = mode.next
        StyleMode.saved = mode
        refreshLabels()
    }

    @objc private func spaceTapped() { textDocumentProxy.insertText(" ") }
    @objc private func returnTapped() { textDocumentProxy.insertText("\n") }

    @objc private func deleteDown() {
        textDocumentProxy.deleteBackward()
        deleteDelay = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                self?.textDocumentProxy.deleteBackward()
            }
        }
    }

    @objc private func deleteUp() {
        deleteDelay?.invalidate(); deleteDelay = nil
        deleteTimer?.invalidate(); deleteTimer = nil
    }
}
