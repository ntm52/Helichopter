import UIKit

// MARK: - Adjustment panel
// A full-panel page of plain choices, so a switch user can change a slider or a
// segmented control, confirm Reset, or read Privacy and Acknowledgements, one press
// at a time. It covers the settings list and owns the scanner until it closes.

extension SettingsPanelView {

    var isAdjusting: Bool { adjustmentPanel != nil }

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
        let title = makeLabel(control.accessibilityLabel ?? "Adjust", size: 22, weight: .bold, color: style.text)
        title.numberOfLines = 0
        let choices = UIStackView(arrangedSubviews: [title])
        choices.axis = .vertical
        choices.spacing = 16
        choices.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(scroll)
        scroll.addSubview(choices)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.topAnchor, constant: 20),
            scroll.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -20),
            choices.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            choices.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -8),
            choices.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
            choices.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
            choices.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -16)
        ])
        func addChoice(_ name: String, action: @escaping () -> Void) {
            let target = ButtonTarget(action)
            adjustmentTargets.append(target)
            let button = plainButton(name, color: style.accent, target: target, action: #selector(ButtonTarget.tapped))
            button.titleLabel?.numberOfLines = 0
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            choices.addArrangedSubview(button)
        }
        if let slider = control as? UISlider {
            let value = makeLabel("", size: 20, weight: .medium, color: style.text)
            func updateValue() {
                value.text = String(format: "Value: %.2g", slider.value)
                for case let button as UIButton in choices.arrangedSubviews {
                    if let name = button.currentTitle, name != "Done" {
                        button.accessibilityLabel = "\(name). \(value.text ?? "")"
                    }
                }
            }
            updateValue()
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
        } else if let segment = control as? UISegmentedControl {
            for index in 0..<segment.numberOfSegments where segment.isEnabledForSegment(at: index) {
                addChoice(segment.titleForSegment(at: index) ?? "Option \(index + 1)") { [weak self, weak segment] in
                    self?.closeAdjustment()
                    segment?.selectedSegmentIndex = index
                    segment?.sendActions(for: .valueChanged)
                    // Scan mode may just have changed; apply it immediately.
                    if self?.switchScanner.isActive == true { self?.startScanning(focusing: control.accessibilityLabel) }
                }
            }
        }
        if control.accessibilityLabel == "Reset Settings" {
            let explanation = makeLabel("Restore Standard difficulty, default controls, theme, and audio. Saved scores and guide completion are kept.", size: 20, weight: .regular, color: style.text)
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
                        "Acknowledgements": AppLinks.acknowledgements][control.accessibilityLabel ?? ""]
            if let info = info {
                let body = makeLabel(info, size: 17, weight: .regular, color: style.text)
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
