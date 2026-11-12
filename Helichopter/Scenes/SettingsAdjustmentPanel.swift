import UIKit

// MARK: - Adjustment panel
// A full-panel page of plain choices, so a switch user can change a slider, confirm
// Reset, or read a long explanation, Privacy, or Acknowledgements, one press at a time. It covers the settings list and owns the scanner until it closes.

extension SettingsPanelView {

    func showAdjustment(for control: UIControl) {
        returnControlLabel = control.accessibilityLabel
        switchScanner.stop()
        let panel = UIView()
        panel.backgroundColor = style.bg.withAlphaComponent(1)
        panel.accessibilityViewIsModal = true
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)
        adjustmentPanel = panel
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: topAnchor), panel.bottomAnchor.constraint(equalTo: bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: leadingAnchor), panel.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        let title = makeLabel(control.accessibilityLabel ?? "Adjust", style: .display, color: style.text)
        title.accessibilityTraits = .header
        title.numberOfLines = 0
        let choices = UIStackView(arrangedSubviews: [title])
        choices.axis = .vertical
        choices.spacing = Spacing.l
        choices.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(scroll)
        scroll.addSubview(choices)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.topAnchor, constant: Spacing.l),
            scroll.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -Spacing.l),
            scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: Spacing.l),
            scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -Spacing.l),
            choices.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: Spacing.s),
            choices.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -Spacing.s),
            choices.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: Spacing.s),
            choices.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -Spacing.s),
            choices.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -Spacing.l)
        ])
        func addChoice(_ name: String, action: @escaping () -> Void) {
            let target = ButtonTarget(action)
            adjustmentTargets.append(target)
            let button = panelButton(name, target: target, action: #selector(ButtonTarget.tapped))
            choices.addArrangedSubview(button)
        }
        // The long explanation of a setting, on its slider's page.
        let name = control.accessibilityLabel ?? ""
        if control is UISlider, let more = infoPages[name] {
            choices.addArrangedSubview(makeLabel(more, style: .body, color: style.text))
        }
        if let slider = control as? UISlider {
            let value = makeLabel("", style: .heading, color: style.accent)
            func updateValue() {
                value.text = "Value: \(slider.spokenValue)"
                for case let button as UIButton in choices.arrangedSubviews {
                    if let name = button.currentTitle, name != "Done" {
                        button.accessibilityLabel = "\(name). \(value.text ?? "")"
                    }
                }
            }
            choices.addArrangedSubview(value)
            for (name, direction) in [("Decrease", Float(-1)), ("Increase", Float(1))] {
                addChoice(name) { [weak slider] in
                    guard let slider = slider else { return }
                    let step = (slider.maximumValue - slider.minimumValue) / 20
                    slider.value = min(slider.maximumValue, max(slider.minimumValue, slider.value + step * direction))
                    slider.sendActions(for: .valueChanged)
                    updateValue()
                    UIAccessibility.post(notification: .announcement, argument: value.text)
                }
            }
            updateValue()
        }
        if control.accessibilityLabel == "Reset Settings" {
            let explanation = makeLabel("Restore Standard difficulty, default controls, audio, the menu theme, and the Classic helicopter and pipes. Saved scores and guide completion are kept.", style: .body, color: style.text)
            explanation.numberOfLines = 0
            choices.addArrangedSubview(explanation)
            addChoice("Cancel") { [weak self] in self?.closeAdjustment() }
            addChoice("Restore Defaults") { [weak self] in
                GameSettings.shared.resetToDefaults()
                self?.closeAdjustment()
                self?.onThemeChanged?()
            }
        } else {
            let info = ["Privacy Policy": AppLinks.privacySummary,
                        "Acknowledgements": AppLinks.acknowledgements][name]
                ?? (control is UIButton ? infoPages[name] : nil)
            if let info = info {
                let body = makeLabel(info, style: .body, color: style.text)
                choices.addArrangedSubview(body)
            }
            if control.accessibilityLabel == "Privacy Policy" {
                addChoice("Open Full Policy in Safari") { UIApplication.shared.open(AppLinks.privacyPolicy) }
            }
            addChoice("Done") { [weak self] in self?.closeAdjustment() }
        }
        switchScanner.items = controls(in: panel).map { scanItem(for: $0) }
        switchScanner.start()
        ScreenChangeAnnouncer.post(title)
    }

    func closeAdjustment() {
        switchScanner.stop()
        adjustmentPanel?.removeFromSuperview()
        adjustmentPanel = nil
        adjustmentTargets.removeAll()
        let label = returnControlLabel
        returnControlLabel = nil
        startScanning(focusing: label)
        ScreenChangeAnnouncer.post(focusedControl)
    }
}
